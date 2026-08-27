// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporary;
  late EncryptedAttachmentStore store;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('localhold-stage4-');
    store = EncryptedAttachmentStore(
      root: temporary,
      cipher: const _TestCipher(),
      creationPolicy: const _AllowCreationPolicy(),
    );
  });

  tearDown(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test('empty, short and multi-chunk attachments round-trip', () async {
    for (final bytes in <Uint8List>[
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      Uint8List(VaultLimits.attachmentChunkBytes + 17)..setAll(
        0,
        List.generate(VaultLimits.attachmentChunkBytes + 17, (i) => i & 255),
      ),
    ]) {
      final id = AttachmentId.generate();
      await store.importEncrypted(
        id: id,
        plaintext: Stream.value(bytes),
        declaredSize: bytes.length,
      );
      final restored = BytesBuilder(copy: false);
      await for (final chunk in store.openVerified(id)) {
        restored.add(Uint8List.fromList(chunk));
      }
      expect(restored.takeBytes(), bytes);
    }
  });

  test('cancelled import never replaces the previous good object', () async {
    final id = AttachmentId.generate();
    await store.importEncrypted(
      id: id,
      plaintext: Stream.value([1, 2, 3]),
      declaredSize: 3,
    );
    final input = StreamController<List<int>>();
    final replacement = store.importEncrypted(
      id: id,
      plaintext: input.stream,
      declaredSize: 4,
    );
    input.add([9, 9]);
    await store.cancel(id);
    input.add([9, 9]);
    await input.close();

    await expectLater(
      replacement,
      throwsA(_failure(VaultFailureCode.sessionLocked)),
    );
    final restored = <int>[];
    await for (final chunk in store.openVerified(id)) {
      restored.addAll(chunk);
    }
    expect(restored, [1, 2, 3]);
  });

  test(
    'expired entitlement permits replacement but not a new attachment',
    () async {
      final existing = AttachmentId.generate();
      await store.importEncrypted(
        id: existing,
        plaintext: Stream.value([1]),
        declaredSize: 1,
      );
      final expiredStore = EncryptedAttachmentStore(
        root: temporary,
        cipher: const _TestCipher(),
        creationPolicy: const CommunityFreeVaultCreationPolicy(),
      );

      await expiredStore.importEncrypted(
        id: existing,
        plaintext: Stream.value([2]),
        declaredSize: 1,
      );
      expect(
        await expiredStore
            .openVerified(existing)
            .expand((value) => value)
            .toList(),
        [2],
      );
      await expectLater(
        expiredStore.importEncrypted(
          id: AttachmentId.generate(),
          plaintext: Stream.value([3]),
          declaredSize: 1,
        ),
        throwsA(_failure(VaultFailureCode.capabilityUnavailable)),
      );
    },
  );

  test('Trash move, restore and permanent cleanup are explicit', () async {
    final id = AttachmentId.generate();
    await store.importEncrypted(
      id: id,
      plaintext: Stream.value([4]),
      declaredSize: 1,
    );
    await store.moveToTrash(id);
    await expectLater(
      store.openVerified(id).drain<void>(),
      throwsA(_failure(VaultFailureCode.objectNotFound)),
    );
    await store.restoreFromTrash(id);
    expect(await store.openVerified(id).expand((value) => value).toList(), [4]);
    await store.permanentlyDelete(id);
    await expectLater(
      store.openVerified(id).drain<void>(),
      throwsA(_failure(VaultFailureCode.objectNotFound)),
    );
  });

  test('interrupted promotion restores the last-good directory', () async {
    final id = AttachmentId.generate();
    await store.importEncrypted(
      id: id,
      plaintext: Stream.value([7, 8]),
      declaredSize: 2,
    );
    final current = Directory(
      '${temporary.path}${Platform.pathSeparator}${id.value}',
    );
    final previous = Directory(
      '${temporary.path}${Platform.pathSeparator}.previous-${id.value}',
    );
    await current.rename(previous.path);
    await Directory(
      '${temporary.path}${Platform.pathSeparator}.staging-${id.value}-synthetic',
    ).create();

    expect(await store.recoverInterruptedOperations(), isEmpty);
    expect(await store.openVerified(id).expand((value) => value).toList(), [
      7,
      8,
    ]);
    expect(await previous.exists(), isFalse);
  });

  test('declared-size mismatch fails atomically in both directions', () async {
    for (final fixture in <({List<int> bytes, int declared})>[
      (bytes: [1, 2, 3], declared: 2),
      (bytes: [1, 2], declared: 3),
    ]) {
      final id = AttachmentId.generate();
      await expectLater(
        store.importEncrypted(
          id: id,
          plaintext: Stream.value(fixture.bytes),
          declaredSize: fixture.declared,
        ),
        throwsA(_failure(VaultFailureCode.integrityFailure)),
      );
      expect(
        await Directory('${temporary.path}${Platform.pathSeparator}${id.value}')
            .exists(),
        isFalse,
      );
    }
  });

  test('synthetic disk-full preserves the previous good attachment', () async {
    final id = AttachmentId.generate();
    await store.importEncrypted(
      id: id,
      plaintext: Stream.value([1, 2, 3]),
      declaredSize: 3,
    );
    final failing = EncryptedAttachmentStore(
      root: temporary,
      cipher: const _FailingCipher(),
      creationPolicy: const _AllowCreationPolicy(),
    );

    await expectLater(
      failing.importEncrypted(
        id: id,
        plaintext: Stream.value([9, 9, 9]),
        declaredSize: 3,
      ),
      throwsA(_failure(VaultFailureCode.storageFull)),
    );
    expect(await store.openVerified(id).expand((value) => value).toList(), [
      1,
      2,
      3,
    ]);
  });

  test('corrupt ciphertext is isolated as an integrity failure', () async {
    final id = AttachmentId.generate();
    await store.importEncrypted(
      id: id,
      plaintext: Stream.value([1, 2, 3]),
      declaredSize: 3,
    );
    final chunk = File(
      '${temporary.path}${Platform.pathSeparator}${id.value}'
      '${Platform.pathSeparator}chunk-0000000000.bin',
    );
    final bytes = await chunk.readAsBytes();
    bytes[0] ^= 0xff;
    await chunk.writeAsBytes(bytes, flush: true);

    await expectLater(
      store.openVerified(id).drain<void>(),
      throwsA(_failure(VaultFailureCode.integrityFailure)),
    );
  });

  test(
    'preview plaintext is session-bound and removed on background',
    () async {
      final id = AttachmentId.generate();
      await store.importEncrypted(
        id: id,
        plaintext: Stream.value([1, 2, 3]),
        declaredSize: 3,
      );
      final coordinator = AttachmentPreviewCoordinator();
      await coordinator.onUnlocked(
        VaultId.parse('AAAAAAAAAAAAAAAAAAAAAA'),
        VaultSessionRef.fromOpaque('preview-session'),
      );
      final previewRoot = Directory(
        '${temporary.path}${Platform.pathSeparator}plaintext-previews',
      );
      final lease = await coordinator.open(
        store: store,
        id: id,
        mimeType: 'text/plain',
        privateTemporaryRoot: previewRoot,
      );
      expect(await lease.file.exists(), isTrue);

      await coordinator.onBackground();

      expect(await lease.file.exists(), isFalse);
      expect(coordinator.hasPendingCleanup, isFalse);
      await expectLater(
        coordinator.open(
          store: store,
          id: id,
          mimeType: 'text/plain',
          privateTemporaryRoot: previewRoot,
        ),
        throwsA(_failure(VaultFailureCode.sessionLocked)),
      );
    },
  );
}

final class _AllowCreationPolicy implements VaultCreationPolicy {
  const _AllowCreationPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

final class _TestCipher implements PayloadCipher {
  @override
  String get vaultId => 'AAAAAAAAAAAAAAAAAAAAAA';

  const _TestCipher();

  @override
  String get keyGenerationId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async =>
      Uint8List.fromList(envelope.map((value) => value ^ 0xa5).toList());

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async =>
      Uint8List.fromList(plaintext.map((value) => value ^ 0xa5).toList());
}

final class _FailingCipher implements PayloadCipher {
  const _FailingCipher();

  @override
  String get vaultId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  String get keyGenerationId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async => throw const FileSystemException('synthetic disk full');

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async => throw const FileSystemException('synthetic disk full');
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:test/test.dart';

const _gib = 1024 * 1024 * 1024;
const _memoryBudgetBytes = 64 * 1024 * 1024;

void main() {
  test('1 GiB round-trip and 5 GiB import remain streaming', () async {
    final root = await Directory.systemTemp.createTemp(
      'localhold-stage4-large-',
    );
    try {
      await _verify(
        root: Directory('${root.path}${Platform.pathSeparator}one-gib'),
        size: _gib,
        readBack: true,
      );
      await _verify(
        root: Directory('${root.path}${Platform.pathSeparator}five-gib'),
        size: 5 * _gib,
        readBack: false,
      );
    } finally {
      if (await root.exists()) await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

Future<void> _verify({
  required Directory root,
  required int size,
  required bool readBack,
}) async {
  final cipher = _CompactZeroCipher();
  final store = EncryptedAttachmentStore(
    root: root,
    cipher: cipher,
    creationPolicy: const _AllowCreationPolicy(),
  );
  final id = AttachmentId.generate();
  final baselineRss = ProcessInfo.currentRss;
  var peakRss = baselineRss;
  final sampler = Timer.periodic(const Duration(milliseconds: 10), (_) {
    final current = ProcessInfo.currentRss;
    if (current > peakRss) peakRss = current;
  });
  final importWatch = Stopwatch()..start();
  try {
    await store.importEncrypted(
      id: id,
      plaintext: _zeroStream(size),
      declaredSize: size,
    );
  } finally {
    importWatch.stop();
    sampler.cancel();
  }
  final expectedChunks =
      (size + VaultLimits.attachmentChunkBytes - 1) ~/
      VaultLimits.attachmentChunkBytes;
  if (cipher.manifestDeclaredSize != size ||
      cipher.manifestChunkCount != expectedChunks) {
    throw StateError('Large attachment manifest mismatch');
  }
  final memoryDelta = peakRss - baselineRss;
  if (memoryDelta > _memoryBudgetBytes) {
    throw StateError('Attachment RSS delta exceeded 64 MiB: $memoryDelta');
  }

  var restored = 0;
  final readWatch = Stopwatch();
  if (readBack) {
    readWatch.start();
    await for (final chunk in store.openVerified(id)) {
      restored += chunk.length;
    }
    readWatch.stop();
    if (restored != size) throw StateError('Large attachment read mismatch');
  }
  stdout.writeln(
    'STAGE4_LARGE_ATTACHMENT size=$size chunks=$expectedChunks '
    'import_ms=${importWatch.elapsedMilliseconds} '
    'read_ms=${readWatch.elapsedMilliseconds} rss_delta_bytes=$memoryDelta '
    'read_back=$readBack',
  );
}

Stream<List<int>> _zeroStream(int size) async* {
  final chunk = Uint8List(VaultLimits.attachmentChunkBytes);
  var remaining = size;
  while (remaining > 0) {
    final take = remaining < chunk.length ? remaining : chunk.length;
    yield take == chunk.length ? chunk : Uint8List(take);
    remaining -= take;
  }
}

final class _CompactZeroCipher implements PayloadCipher {
  Uint8List? _manifest;
  int? manifestDeclaredSize;
  int? manifestChunkCount;

  @override
  String get vaultId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  String get keyGenerationId => 'KKKKKKKKKKKKKKKKKKKKKK';

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async {
    final aad = ascii.decode(authenticatedData);
    if (aad.startsWith('localhold.attachment.manifest.v1|')) {
      _manifest = Uint8List.fromList(plaintext);
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>;
      manifestDeclaredSize = json['declaredSize']! as int;
      manifestChunkCount = json['chunkCount']! as int;
    }
    return Uint8List.fromList([0xa5]);
  }

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async {
    final aad = ascii.decode(authenticatedData);
    if (aad.startsWith('localhold.attachment.manifest.v1|')) {
      final manifest = _manifest;
      if (manifest == null) throw StateError('Manifest not captured');
      return Uint8List.fromList(manifest);
    }
    final parts = aad.split('|');
    if (parts.length != 6 || parts.first != 'localhold.attachment.chunk.v1') {
      throw StateError('Unexpected attachment AAD');
    }
    final index = int.parse(parts[4]);
    final declaredSize = int.parse(parts[5]);
    final offset = index * VaultLimits.attachmentChunkBytes;
    final remaining = declaredSize - offset;
    final length = remaining < VaultLimits.attachmentChunkBytes
        ? remaining
        : VaultLimits.attachmentChunkBytes;
    if (length < 0) throw StateError('Invalid attachment AAD bounds');
    return Uint8List(length);
  }
}

final class _AllowCreationPolicy implements VaultCreationPolicy {
  const _AllowCreationPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

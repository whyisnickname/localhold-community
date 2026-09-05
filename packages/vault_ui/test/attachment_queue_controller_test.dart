// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test('Free policy rejects attachment before platform acquisition', () {
    final acquisition = _SequentialAcquisition();
    final controller = AttachmentQueueController(
      coordinator: AttachmentIntakeCoordinator(
        acquisition: acquisition,
        store: _BlockingStore(),
      ),
      creationPolicy: const CommunityFreeVaultCreationPolicy(),
    );
    addTearDown(controller.dispose);
    expect(
      () => controller.enqueue(AttachmentSourceKind.file),
      throwsA(isA<VaultFailure>()),
    );
    expect(acquisition.calls, 0);
  });

  test('attachment queue runs imports serially', () async {
    final acquisition = _SequentialAcquisition();
    final store = _BlockingStore();
    final controller = AttachmentQueueController(
      coordinator: AttachmentIntakeCoordinator(
        acquisition: acquisition,
        store: store,
      ),
      creationPolicy: const _AllowPolicy(),
    );
    addTearDown(controller.dispose);
    controller.enqueue(AttachmentSourceKind.file);
    controller.enqueue(AttachmentSourceKind.photoPicker);
    await Future<void>.delayed(Duration.zero);
    expect(acquisition.calls, 1);
    expect(store.maximumActive, 1);

    store.releaseNext();
    await _until(() => acquisition.calls == 2);
    expect(store.maximumActive, 1);
    store.releaseNext();
    await _until(
      () => controller.items.every(
        (item) => item.status == AttachmentQueueStatus.imported,
      ),
    );
  });
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

final class _SequentialAcquisition implements AttachmentAcquisitionPort {
  int calls = 0;

  @override
  Future<AttachmentAcquisitionResult> acquire(AttachmentSourceKind kind) async {
    calls++;
    return AttachmentAcquisitionResult.ready(
      AttachmentSource(
        displayName: 'file-$calls.bin',
        mimeType: 'application/octet-stream',
        declaredSize: 1,
        bytes: Stream.value([calls]),
      ),
    );
  }
}

final class _BlockingStore implements AttachmentCipherStore {
  final List<Completer<void>> _releases = [];
  int _active = 0;
  int maximumActive = 0;

  void releaseNext() =>
      _releases.firstWhere((value) => !value.isCompleted).complete();

  @override
  Future<void> importEncrypted({
    required AttachmentId id,
    required Stream<List<int>> plaintext,
    required int declaredSize,
  }) async {
    _active++;
    maximumActive = maximumActive < _active ? _active : maximumActive;
    final release = Completer<void>();
    _releases.add(release);
    await for (final _ in plaintext) {}
    await release.future;
    _active--;
  }

  @override
  Future<void> cancel(AttachmentId id) async {}

  @override
  Stream<Uint8List> openVerified(AttachmentId id) => const Stream.empty();

  @override
  Future<void> moveToTrash(AttachmentId id) async {}

  @override
  Future<void> permanentlyDelete(AttachmentId id) async {}

  @override
  Future<void> restoreFromTrash(AttachmentId id) async {}
}

final class _AllowPolicy implements VaultCreationPolicy {
  const _AllowPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'selected source streams directly into encrypted store with progress',
    () async {
      final acquisition = _Acquisition(
        AttachmentAcquisitionResult.ready(
          AttachmentSource(
            displayName: 'photo.jpg',
            mimeType: 'image/jpeg',
            declaredSize: 4,
            bytes: Stream.fromIterable([
              [1, 2],
              [3, 4],
            ]),
          ),
        ),
      );
      final store = _Store();
      final progress = <int>[];
      final result =
          await AttachmentIntakeCoordinator(
            acquisition: acquisition,
            store: store,
          ).import(
            AttachmentSourceKind.photoPicker,
            onProgress: (value) => progress.add(value.processedBytes),
          );

      expect(acquisition.requested, [AttachmentSourceKind.photoPicker]);
      expect(result.status, AttachmentIntakeStatus.imported);
      expect(store.bytes, [1, 2, 3, 4]);
      expect(progress, [0, 2, 4]);
      expect(store.cancelled, isFalse);
      expect(result.toVaultValue(), containsPair('displayName', 'photo.jpg'));
      expect(result.toVaultValue().keys, isNot(contains('path')));
    },
  );

  test('permission denial does not create or clean an attachment', () async {
    final acquisition = _Acquisition(
      const AttachmentAcquisitionResult.permissionDenied(),
    );
    final store = _Store();
    final result = await AttachmentIntakeCoordinator(
      acquisition: acquisition,
      store: store,
    ).import(AttachmentSourceKind.camera);
    expect(result.status, AttachmentIntakeStatus.permissionDenied);
    expect(store.imports, 0);
    expect(store.cancelled, isFalse);
  });

  test(
    'platform acquisition exception becomes a closed failure result',
    () async {
      final store = _Store();
      final result = await AttachmentIntakeCoordinator(
        acquisition: _ThrowingAcquisition(),
        store: store,
      ).import(AttachmentSourceKind.file);
      expect(result.status, AttachmentIntakeStatus.failed);
      expect(result.failureCode, VaultFailureCode.internalFailure);
      expect(store.imports, 0);
    },
  );

  test(
    'size mismatch and cancellation clean partial encrypted output',
    () async {
      final mismatchStore = _Store();
      final mismatch = await AttachmentIntakeCoordinator(
        acquisition: _Acquisition(
          AttachmentAcquisitionResult.ready(
            AttachmentSource(
              displayName: 'file.bin',
              mimeType: 'application/octet-stream',
              declaredSize: 3,
              bytes: Stream.value([1, 2]),
            ),
          ),
        ),
        store: mismatchStore,
      ).import(AttachmentSourceKind.file);
      expect(mismatch.status, AttachmentIntakeStatus.failed);
      expect(mismatchStore.cancelled, isTrue);

      final cancellation = AttachmentImportCancellation()..cancel();
      final cancelledStore = _Store();
      final cancelled = await AttachmentIntakeCoordinator(
        acquisition: _Acquisition(
          AttachmentAcquisitionResult.ready(
            AttachmentSource(
              displayName: 'file.bin',
              mimeType: 'application/octet-stream',
              declaredSize: 2,
              bytes: Stream.value([1, 2]),
            ),
          ),
        ),
        store: cancelledStore,
      ).import(AttachmentSourceKind.file, cancellation: cancellation);
      expect(cancelled.status, AttachmentIntakeStatus.cancelled);
      expect(cancelledStore.cancelled, isTrue);
    },
  );
}

final class _Acquisition implements AttachmentAcquisitionPort {
  _Acquisition(this.result);

  final AttachmentAcquisitionResult result;
  final List<AttachmentSourceKind> requested = [];

  @override
  Future<AttachmentAcquisitionResult> acquire(AttachmentSourceKind kind) async {
    requested.add(kind);
    return result;
  }
}

final class _ThrowingAcquisition implements AttachmentAcquisitionPort {
  @override
  Future<AttachmentAcquisitionResult> acquire(AttachmentSourceKind kind) async {
    throw StateError('closed platform failure');
  }
}

final class _Store implements AttachmentCipherStore {
  int imports = 0;
  bool cancelled = false;
  final List<int> bytes = [];

  @override
  Future<void> importEncrypted({
    required AttachmentId id,
    required Stream<List<int>> plaintext,
    required int declaredSize,
  }) async {
    imports++;
    await for (final chunk in plaintext) {
      bytes.addAll(chunk);
    }
  }

  @override
  Future<void> cancel(AttachmentId id) async {
    cancelled = true;
  }

  @override
  Stream<Uint8List> openVerified(AttachmentId id) => const Stream.empty();

  @override
  Future<void> moveToTrash(AttachmentId id) async {}

  @override
  Future<void> permanentlyDelete(AttachmentId id) async {}

  @override
  Future<void> restoreFromTrash(AttachmentId id) async {}
}

// SPDX-License-Identifier: MPL-2.0

// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'attachment.dart';
import 'errors.dart';
import 'identifiers.dart';

enum AttachmentSourceKind { file, photoPicker, camera }

enum AttachmentAcquisitionStatus {
  ready,
  cancelled,
  permissionDenied,
  unavailable,
}

final class AttachmentSource {
  AttachmentSource({
    required this.displayName,
    required this.mimeType,
    required this.declaredSize,
    required this.bytes,
  }) {
    if (displayName.trim().isEmpty ||
        displayName.length > 512 ||
        mimeType.trim().isEmpty ||
        mimeType.length > 256 ||
        declaredSize < 0) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final String displayName;
  final String mimeType;
  final int declaredSize;
  final Stream<List<int>> bytes;
}

final class AttachmentAcquisitionResult {
  const AttachmentAcquisitionResult.ready(this.source)
    : status = AttachmentAcquisitionStatus.ready;

  const AttachmentAcquisitionResult.cancelled()
    : status = AttachmentAcquisitionStatus.cancelled,
      source = null;

  const AttachmentAcquisitionResult.permissionDenied()
    : status = AttachmentAcquisitionStatus.permissionDenied,
      source = null;

  const AttachmentAcquisitionResult.unavailable()
    : status = AttachmentAcquisitionStatus.unavailable,
      source = null;

  final AttachmentAcquisitionStatus status;
  final AttachmentSource? source;
}

abstract interface class AttachmentAcquisitionPort {
  /// Requests any required permission only for the explicitly selected kind.
  Future<AttachmentAcquisitionResult> acquire(AttachmentSourceKind kind);
}

final class AttachmentImportCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

final class AttachmentImportProgress {
  const AttachmentImportProgress({
    required this.processedBytes,
    required this.declaredBytes,
  });

  final int processedBytes;
  final int declaredBytes;

  double get fraction =>
      declaredBytes == 0 ? 1 : (processedBytes / declaredBytes).clamp(0, 1);
}

enum AttachmentIntakeStatus {
  imported,
  cancelled,
  permissionDenied,
  unavailable,
  failed,
}

final class AttachmentIntakeResult {
  const AttachmentIntakeResult._({
    required this.status,
    this.attachmentId,
    this.displayName,
    this.mimeType,
    this.declaredSize,
    this.failureCode,
  });

  const AttachmentIntakeResult.imported({
    required AttachmentId attachmentId,
    required String displayName,
    required String mimeType,
    required int declaredSize,
  }) : this._(
         status: AttachmentIntakeStatus.imported,
         attachmentId: attachmentId,
         displayName: displayName,
         mimeType: mimeType,
         declaredSize: declaredSize,
       );

  const AttachmentIntakeResult.cancelled()
    : this._(status: AttachmentIntakeStatus.cancelled);

  const AttachmentIntakeResult.permissionDenied()
    : this._(status: AttachmentIntakeStatus.permissionDenied);

  const AttachmentIntakeResult.unavailable()
    : this._(status: AttachmentIntakeStatus.unavailable);

  const AttachmentIntakeResult.failed(VaultFailureCode code)
    : this._(status: AttachmentIntakeStatus.failed, failureCode: code);

  final AttachmentIntakeStatus status;
  final AttachmentId? attachmentId;
  final String? displayName;
  final String? mimeType;
  final int? declaredSize;
  final VaultFailureCode? failureCode;

  Map<String, Object?> toVaultValue() {
    if (status != AttachmentIntakeStatus.imported || attachmentId == null) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    return {
      'schemaVersion': 1,
      'attachmentId': attachmentId!.value,
      'displayName': displayName,
      'mimeType': mimeType,
      'declaredSize': declaredSize,
    };
  }
}

final class AttachmentIntakeCoordinator {
  const AttachmentIntakeCoordinator({
    required AttachmentAcquisitionPort acquisition,
    required AttachmentCipherStore store,
  }) : _acquisition = acquisition,
       _store = store;

  final AttachmentAcquisitionPort _acquisition;
  final AttachmentCipherStore _store;

  Future<AttachmentIntakeResult> import(
    AttachmentSourceKind kind, {
    AttachmentImportCancellation? cancellation,
    void Function(AttachmentImportProgress progress)? onProgress,
  }) async {
    final AttachmentAcquisitionResult acquired;
    try {
      acquired = await _acquisition.acquire(kind);
    } on VaultFailure catch (failure) {
      return AttachmentIntakeResult.failed(failure.code);
    } on Object {
      return const AttachmentIntakeResult.failed(
        VaultFailureCode.internalFailure,
      );
    }
    switch (acquired.status) {
      case AttachmentAcquisitionStatus.cancelled:
        return const AttachmentIntakeResult.cancelled();
      case AttachmentAcquisitionStatus.permissionDenied:
        return const AttachmentIntakeResult.permissionDenied();
      case AttachmentAcquisitionStatus.unavailable:
        return const AttachmentIntakeResult.unavailable();
      case AttachmentAcquisitionStatus.ready:
        break;
    }
    final source = acquired.source;
    if (source == null) {
      return const AttachmentIntakeResult.failed(
        VaultFailureCode.internalFailure,
      );
    }
    final id = AttachmentId.generate();
    try {
      await _store.importEncrypted(
        id: id,
        plaintext: _validatedStream(
          source,
          cancellation: cancellation,
          onProgress: onProgress,
        ),
        declaredSize: source.declaredSize,
      );
      if (cancellation?.isCancelled ?? false) {
        throw const _AttachmentImportCancelled();
      }
      return AttachmentIntakeResult.imported(
        attachmentId: id,
        displayName: source.displayName,
        mimeType: source.mimeType,
        declaredSize: source.declaredSize,
      );
    } on _AttachmentImportCancelled {
      await _cleanup(id);
      return const AttachmentIntakeResult.cancelled();
    } on VaultFailure catch (failure) {
      await _cleanup(id);
      return AttachmentIntakeResult.failed(failure.code);
    } on Object {
      await _cleanup(id);
      return const AttachmentIntakeResult.failed(
        VaultFailureCode.internalFailure,
      );
    }
  }

  Stream<List<int>> _validatedStream(
    AttachmentSource source, {
    required AttachmentImportCancellation? cancellation,
    required void Function(AttachmentImportProgress progress)? onProgress,
  }) async* {
    var processed = 0;
    onProgress?.call(
      AttachmentImportProgress(
        processedBytes: 0,
        declaredBytes: source.declaredSize,
      ),
    );
    await for (final chunk in source.bytes) {
      if (cancellation?.isCancelled ?? false) {
        throw const _AttachmentImportCancelled();
      }
      if (chunk.isEmpty) continue;
      processed += chunk.length;
      if (processed > source.declaredSize) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      yield chunk;
      onProgress?.call(
        AttachmentImportProgress(
          processedBytes: processed,
          declaredBytes: source.declaredSize,
        ),
      );
    }
    if (cancellation?.isCancelled ?? false) {
      throw const _AttachmentImportCancelled();
    }
    if (processed != source.declaredSize) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  Future<void> _cleanup(AttachmentId id) async {
    try {
      await _store.cancel(id);
    } on Object {
      // Cleanup is best-effort here; the store owns its crash-safe staging
      // cleanup and must not replace the original closed failure result.
    }
  }
}

final class _AttachmentImportCancelled implements Exception {
  const _AttachmentImportCancelled();
}

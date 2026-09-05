// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';
import 'identifiers.dart';

enum LauncherShortcutAction { add, search, lock }

extension LauncherShortcutActionSafeId on LauncherShortcutAction {
  String get safeId => switch (this) {
    LauncherShortcutAction.add => 'localhold.add',
    LauncherShortcutAction.search => 'localhold.search',
    LauncherShortcutAction.lock => 'localhold.lock',
  };
}

enum InboundShareKind { text, url, file, image }

abstract final class InboundShareLimits {
  static const maximumInlineBytes = 64 * 1024;
  static const maximumStagedFileBytes = 256 * 1024 * 1024;
  static const maximumLifetime = Duration(hours: 24);
}

final class InboundShareDescriptor {
  InboundShareDescriptor({
    required this.id,
    required this.kind,
    required this.byteLength,
    required this.receivedAt,
    required this.expiresAt,
  }) {
    final maximum = switch (kind) {
      InboundShareKind.text ||
      InboundShareKind.url => InboundShareLimits.maximumInlineBytes,
      InboundShareKind.file ||
      InboundShareKind.image => InboundShareLimits.maximumStagedFileBytes,
    };
    if (!receivedAt.isUtc ||
        !expiresAt.isUtc ||
        byteLength < 1 ||
        byteLength > maximum ||
        !expiresAt.isAfter(receivedAt) ||
        expiresAt.difference(receivedAt) > InboundShareLimits.maximumLifetime) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final PendingShareId id;
  final InboundShareKind kind;
  final int byteLength;
  final DateTime receivedAt;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  @override
  String toString() =>
      'InboundShareDescriptor(${id.value}, ${kind.name}, $byteLength, '
      '$receivedAt, $expiresAt)';
}

abstract interface class InboundShareStagingPort {
  Future<List<InboundShareDescriptor>> list();
  Stream<List<int>> open(PendingShareId id);
  Future<void> delete(PendingShareId id);
  Future<void> purgeExpired(DateTime now);
}

/// Implementations must commit the encrypted draft only after fully consuming
/// and validating [plaintext]. A thrown stream error must leave no partial
/// encrypted draft or attachment.
abstract interface class EncryptedInboundDraftSink {
  Future<DraftId> createFromShare({
    required InboundShareKind kind,
    required int byteLength,
    required Stream<List<int>> plaintext,
  });
}

enum InboundShareStatus { imported, expired, cancelled, failed }

final class InboundShareResult {
  const InboundShareResult._(this.status, this.draftId);
  const InboundShareResult.imported(DraftId id)
    : this._(InboundShareStatus.imported, id);
  const InboundShareResult.expired() : this._(InboundShareStatus.expired, null);
  const InboundShareResult.cancelled()
    : this._(InboundShareStatus.cancelled, null);
  const InboundShareResult.failed() : this._(InboundShareStatus.failed, null);

  final InboundShareStatus status;
  final DraftId? draftId;
}

final class InboundShareCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

final class InboundShareCoordinator {
  const InboundShareCoordinator({
    required InboundShareStagingPort staging,
    required EncryptedInboundDraftSink encryptedDraftSink,
  }) : this._(staging, encryptedDraftSink);

  const InboundShareCoordinator._(this._staging, this._encryptedDraftSink);

  final InboundShareStagingPort _staging;
  final EncryptedInboundDraftSink _encryptedDraftSink;

  Future<InboundShareResult> consume(
    InboundShareDescriptor descriptor, {
    required DateTime now,
    InboundShareCancellation? cancellation,
  }) async {
    if (descriptor.isExpiredAt(now)) {
      await _delete(descriptor.id);
      return const InboundShareResult.expired();
    }
    if (cancellation?.isCancelled ?? false) {
      await _delete(descriptor.id);
      return const InboundShareResult.cancelled();
    }
    var completed = false;
    var processed = 0;
    Stream<List<int>> validated() async* {
      await for (final chunk in _staging.open(descriptor.id)) {
        if (cancellation?.isCancelled ?? false) {
          throw const _InboundShareCancelled();
        }
        if (chunk.isEmpty) continue;
        processed += chunk.length;
        if (processed > descriptor.byteLength) {
          throw const VaultFailure(VaultFailureCode.invalidInput);
        }
        yield chunk;
      }
      if (processed != descriptor.byteLength) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      completed = true;
    }

    try {
      final draftId = await _encryptedDraftSink.createFromShare(
        kind: descriptor.kind,
        byteLength: descriptor.byteLength,
        plaintext: validated(),
      );
      if (!completed || processed != descriptor.byteLength) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      await _delete(descriptor.id);
      return InboundShareResult.imported(draftId);
    } on _InboundShareCancelled {
      await _delete(descriptor.id);
      return const InboundShareResult.cancelled();
    } on Object {
      await _delete(descriptor.id);
      return const InboundShareResult.failed();
    }
  }

  Future<void> _delete(PendingShareId id) async {
    try {
      await _staging.delete(id);
    } on Object {
      // The native staging port must also purge stale input on every safe app
      // startup. Cleanup failure cannot expose the payload in Dart state.
    }
  }
}

final class _InboundShareCancelled implements Exception {
  const _InboundShareCancelled();
}

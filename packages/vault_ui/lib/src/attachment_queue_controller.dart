// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

enum AttachmentQueueStatus {
  queued,
  importing,
  imported,
  cancelled,
  permissionDenied,
  unavailable,
  failed,
}

@immutable
final class AttachmentQueueItem {
  const AttachmentQueueItem({
    required this.id,
    required this.kind,
    required this.status,
    this.progress = 0,
    this.result,
  });

  final int id;
  final AttachmentSourceKind kind;
  final AttachmentQueueStatus status;
  final double progress;
  final AttachmentIntakeResult? result;

  AttachmentQueueItem copyWith({
    AttachmentQueueStatus? status,
    double? progress,
    AttachmentIntakeResult? result,
  }) => AttachmentQueueItem(
    id: id,
    kind: kind,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    result: result ?? this.result,
  );
}

final class AttachmentQueueController extends ChangeNotifier {
  AttachmentQueueController({
    required AttachmentIntakeCoordinator coordinator,
    required VaultCreationPolicy creationPolicy,
    this.onImported,
  }) : _coordinator = coordinator,
       _creationPolicy = creationPolicy;

  final AttachmentIntakeCoordinator _coordinator;
  final VaultCreationPolicy _creationPolicy;
  final ValueChanged<AttachmentIntakeResult>? onImported;
  final List<AttachmentQueueItem> _items = [];
  final Map<int, AttachmentImportCancellation> _cancellations = {};
  bool _draining = false;
  bool _disposed = false;
  int _nextId = 1;

  List<AttachmentQueueItem> get items => List.unmodifiable(_items);

  int enqueue(AttachmentSourceKind kind) {
    _creationPolicy.requireAllowed(VaultCreationCapability.customField);
    _creationPolicy.requireAllowed(VaultCreationCapability.attachment);
    final id = _nextId++;
    _items.add(
      AttachmentQueueItem(
        id: id,
        kind: kind,
        status: AttachmentQueueStatus.queued,
      ),
    );
    _notify();
    unawaited(_drain());
    return id;
  }

  void cancel(int id) {
    final index = _index(id);
    if (index < 0) return;
    final item = _items[index];
    if (item.status == AttachmentQueueStatus.queued) {
      _items[index] = item.copyWith(status: AttachmentQueueStatus.cancelled);
      _notify();
      return;
    }
    _cancellations[id]?.cancel();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (!_disposed) {
        final index = _items.indexWhere(
          (item) => item.status == AttachmentQueueStatus.queued,
        );
        if (index < 0) return;
        final item = _items[index];
        final cancellation = AttachmentImportCancellation();
        _cancellations[item.id] = cancellation;
        _items[index] = item.copyWith(status: AttachmentQueueStatus.importing);
        _notify();
        final result = await _coordinator.import(
          item.kind,
          cancellation: cancellation,
          onProgress: (progress) {
            final current = _index(item.id);
            if (current < 0 || _disposed) return;
            _items[current] = _items[current].copyWith(
              progress: progress.fraction,
            );
            _notify();
          },
        );
        _cancellations.remove(item.id);
        final current = _index(item.id);
        if (current < 0) continue;
        _items[current] = _items[current].copyWith(
          status: _queueStatus(result.status),
          progress: result.status == AttachmentIntakeStatus.imported ? 1 : null,
          result: result,
        );
        if (!_disposed && result.status == AttachmentIntakeStatus.imported) {
          onImported?.call(result);
        }
        _notify();
      }
    } finally {
      _draining = false;
    }
  }

  int _index(int id) => _items.indexWhere((item) => item.id == id);

  AttachmentQueueStatus _queueStatus(AttachmentIntakeStatus status) =>
      switch (status) {
        AttachmentIntakeStatus.imported => AttachmentQueueStatus.imported,
        AttachmentIntakeStatus.cancelled => AttachmentQueueStatus.cancelled,
        AttachmentIntakeStatus.permissionDenied =>
          AttachmentQueueStatus.permissionDenied,
        AttachmentIntakeStatus.unavailable => AttachmentQueueStatus.unavailable,
        AttachmentIntakeStatus.failed => AttachmentQueueStatus.failed,
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final cancellation in _cancellations.values) {
      cancellation.cancel();
    }
    super.dispose();
  }
}

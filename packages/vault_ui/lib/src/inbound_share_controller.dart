// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

enum InboundShareViewStatus {
  initial,
  loading,
  ready,
  empty,
  importing,
  imported,
  recoverableFailure,
  locked,
}

@immutable
final class InboundShareViewState {
  InboundShareViewState({
    required this.status,
    required Iterable<InboundShareDescriptor> descriptors,
    this.importedDraftId,
  }) : descriptors = List.unmodifiable(descriptors);

  factory InboundShareViewState.initial() => InboundShareViewState(
    status: InboundShareViewStatus.initial,
    descriptors: const [],
  );

  final InboundShareViewStatus status;
  final List<InboundShareDescriptor> descriptors;
  final DraftId? importedDraftId;

  InboundShareViewState copyWith({
    InboundShareViewStatus? status,
    Iterable<InboundShareDescriptor>? descriptors,
    DraftId? importedDraftId,
    bool clearDraft = false,
  }) => InboundShareViewState(
    status: status ?? this.status,
    descriptors: descriptors ?? this.descriptors,
    importedDraftId: clearDraft
        ? null
        : (importedDraftId ?? this.importedDraftId),
  );

  @override
  String toString() =>
      'InboundShareViewState(${status.name}, count: ${descriptors.length}, '
      'imported: ${importedDraftId != null})';
}

final class InboundShareController extends ChangeNotifier {
  InboundShareController({
    required InboundShareStagingPort staging,
    required InboundShareCoordinator coordinator,
    DateTime Function()? now,
  }) : _staging = staging,
       _coordinator = coordinator,
       _now = now ?? (() => DateTime.now().toUtc());

  final InboundShareStagingPort _staging;
  final InboundShareCoordinator _coordinator;
  final DateTime Function() _now;
  bool _disposed = false;
  int _generation = 0;
  InboundShareViewState _state = InboundShareViewState.initial();

  InboundShareViewState get state => _state;

  Future<void> load() async {
    final generation = ++_generation;
    _emit(
      _state.copyWith(status: InboundShareViewStatus.loading, clearDraft: true),
    );
    try {
      final now = _now().toUtc();
      await _staging.purgeExpired(now);
      final descriptors =
          (await _staging.list())
              .where((descriptor) => !descriptor.isExpiredAt(now))
              .toList(growable: false)
            ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          status: descriptors.isEmpty
              ? InboundShareViewStatus.empty
              : InboundShareViewStatus.ready,
          descriptors: descriptors,
          clearDraft: true,
        ),
      );
    } on Object {
      if (_isCurrent(generation)) {
        _emit(
          _state.copyWith(
            status: InboundShareViewStatus.recoverableFailure,
            descriptors: const [],
            clearDraft: true,
          ),
        );
      }
    }
  }

  Future<void> import(PendingShareId id) async {
    final descriptor = _state.descriptors
        .where((value) => value.id == id)
        .firstOrNull;
    if (descriptor == null) return;
    final generation = _generation;
    _emit(_state.copyWith(status: InboundShareViewStatus.importing));
    final result = await _coordinator.consume(descriptor, now: _now().toUtc());
    if (!_isCurrent(generation)) return;
    final remaining = _state.descriptors
        .where((value) => value.id != id)
        .toList(growable: false);
    _emit(
      _state.copyWith(
        status: switch (result.status) {
          InboundShareStatus.imported => InboundShareViewStatus.imported,
          InboundShareStatus.expired || InboundShareStatus.cancelled =>
            remaining.isEmpty
                ? InboundShareViewStatus.empty
                : InboundShareViewStatus.ready,
          InboundShareStatus.failed =>
            InboundShareViewStatus.recoverableFailure,
        },
        descriptors: remaining,
        importedDraftId: result.draftId,
        clearDraft: result.draftId == null,
      ),
    );
  }

  Future<void> discard(PendingShareId id) async {
    try {
      await _staging.delete(id);
      final remaining = _state.descriptors
          .where((value) => value.id != id)
          .toList(growable: false);
      _emit(
        _state.copyWith(
          status: remaining.isEmpty
              ? InboundShareViewStatus.empty
              : InboundShareViewStatus.ready,
          descriptors: remaining,
        ),
      );
    } on Object {
      _emit(_state.copyWith(status: InboundShareViewStatus.recoverableFailure));
    }
  }

  void onBackgroundOrLock() {
    _generation++;
    _emit(
      InboundShareViewState(
        status: InboundShareViewStatus.locked,
        descriptors: const [],
      ),
    );
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _emit(InboundShareViewState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _state = InboundShareViewState(
      status: InboundShareViewStatus.locked,
      descriptors: const [],
    );
    super.dispose();
  }
}

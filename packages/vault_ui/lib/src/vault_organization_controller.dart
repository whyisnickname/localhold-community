// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

enum VaultOrganizationStatus {
  initial,
  loading,
  ready,
  empty,
  recoverableFailure,
  readOnly,
  locked,
}

@immutable
final class VaultOrganizationLoadData {
  VaultOrganizationLoadData({
    required this.organization,
    required Iterable<VaultRecord> records,
    required this.persisted,
  }) : records = List.unmodifiable(records);

  final VaultOrganization organization;
  final List<VaultRecord> records;
  final bool persisted;
}

abstract interface class VaultOrganizationDataPort {
  Future<VaultOrganizationLoadData> load();

  Future<VaultOrganization> saveOrganization({
    required VaultOrganization organization,
    required bool persisted,
  });

  Future<EncryptedOrganizationMutationResult> saveOrganizationWithRecords({
    required VaultOrganization organization,
    required List<VaultRecord> records,
    required DateTime now,
  });
}

@immutable
final class VaultOrganizationState {
  const VaultOrganizationState({
    required this.status,
    required this.folders,
    required this.tags,
    this.failure = false,
  });

  factory VaultOrganizationState.initial() => const VaultOrganizationState(
    status: VaultOrganizationStatus.initial,
    folders: [],
    tags: [],
  );

  final VaultOrganizationStatus status;
  final List<VaultFolder> folders;
  final List<VaultTag> tags;
  final bool failure;
}

final class VaultOrganizationController extends ChangeNotifier {
  VaultOrganizationController({required VaultOrganizationDataPort data})
    : _data = data;

  final VaultOrganizationDataPort _data;
  VaultOrganization? _organization;
  List<VaultRecord> _records = const [];
  bool _persisted = false;
  bool _disposed = false;
  int _generation = 0;
  VaultOrganizationState _state = VaultOrganizationState.initial();

  VaultOrganizationState get state => _state;

  Future<void> load() async {
    final generation = ++_generation;
    _emit(
      const VaultOrganizationState(
        status: VaultOrganizationStatus.loading,
        folders: [],
        tags: [],
      ),
    );
    try {
      final loaded = await _data.load();
      if (!_isCurrent(generation)) return;
      _organization = loaded.organization;
      _records = loaded.records;
      _persisted = loaded.persisted;
      _emitReady();
    } on VaultFailure catch (failure) {
      if (_isCurrent(generation)) _emitFailure(failure.code);
    } on Object {
      if (_isCurrent(generation)) {
        _emitFailure(VaultFailureCode.internalFailure);
      }
    }
  }

  List<VaultFolder> breadcrumb(FolderId id) =>
      VaultOrganizationMutations.breadcrumb(_requireOrganization(), id);

  Future<void> addFolder(String name, {FolderId? parentId}) =>
      _applyOrganizationTransform(
        () => VaultOrganizationMutations.addFolder(
          _requireOrganization(),
          VaultFolder(id: FolderId.generate(), name: name, parentId: parentId),
        ),
      );

  Future<void> renameFolder(FolderId id, String name) =>
      _applyOrganizationTransform(
        () => VaultOrganizationMutations.renameFolder(
          _requireOrganization(),
          id,
          name,
        ),
      );

  Future<void> moveFolder(FolderId id, FolderId? parentId) =>
      _applyOrganizationTransform(
        () => VaultOrganizationMutations.moveFolder(
          _requireOrganization(),
          id,
          parentId,
        ),
      );

  Future<void> deleteFolder(FolderId id, {required DateTime now}) =>
      _applyOrganizationRecordTransform(
        () => VaultOrganizationMutations.deleteFolder(
          organization: _requireOrganization(),
          records: _records,
          folderId: id,
          now: now,
        ),
        now: now,
      );

  Future<void> addTag(String name) => _applyOrganizationTransform(
    () => VaultOrganizationMutations.addTag(
      _requireOrganization(),
      VaultTag(id: TagId.generate(), name: name),
    ),
  );

  Future<void> renameTag(TagId id, String name) => _applyOrganizationTransform(
    () =>
        VaultOrganizationMutations.renameTag(_requireOrganization(), id, name),
  );

  Future<void> mergeTag(TagId source, TagId target, {required DateTime now}) =>
      _applyOrganizationRecordTransform(
        () => VaultOrganizationMutations.mergeTag(
          organization: _requireOrganization(),
          records: _records,
          sourceId: source,
          targetId: target,
          now: now,
        ),
        now: now,
      );

  Future<void> deleteTag(TagId id, {required DateTime now}) =>
      _applyOrganizationRecordTransform(
        () => VaultOrganizationMutations.deleteTag(
          organization: _requireOrganization(),
          records: _records,
          tagId: id,
          now: now,
        ),
        now: now,
      );

  Future<void> _applyOrganizationTransform(
    VaultOrganization Function() transform,
  ) async {
    try {
      await _saveOrganization(transform());
    } on VaultFailure catch (failure) {
      _emitFailure(failure.code, retainValues: true);
    } on Object {
      _emitFailure(VaultFailureCode.internalFailure, retainValues: true);
    }
  }

  Future<void> _applyOrganizationRecordTransform(
    VaultOrganizationMutationResult Function() transform, {
    required DateTime now,
  }) async {
    try {
      await _saveOrganizationWithRecords(transform(), now: now);
    } on VaultFailure catch (failure) {
      _emitFailure(failure.code, retainValues: true);
    } on Object {
      _emitFailure(VaultFailureCode.internalFailure, retainValues: true);
    }
  }

  Future<void> _saveOrganization(VaultOrganization proposed) async {
    final generation = _generation;
    try {
      final saved = await _data.saveOrganization(
        organization: proposed,
        persisted: _persisted,
      );
      if (!_isCurrent(generation)) return;
      _organization = saved;
      _persisted = true;
      _emitReady();
    } on VaultFailure catch (failure) {
      if (_isCurrent(generation)) {
        _emitFailure(failure.code, retainValues: true);
      }
    } on Object {
      if (_isCurrent(generation)) {
        _emitFailure(VaultFailureCode.internalFailure, retainValues: true);
      }
    }
  }

  Future<void> _saveOrganizationWithRecords(
    VaultOrganizationMutationResult proposed, {
    required DateTime now,
  }) async {
    if (!_persisted) {
      _emitFailure(VaultFailureCode.capabilityUnavailable, retainValues: true);
      return;
    }
    final generation = _generation;
    try {
      final saved = await _data.saveOrganizationWithRecords(
        organization: proposed.organization,
        records: proposed.records,
        now: now,
      );
      if (!_isCurrent(generation)) return;
      _organization = saved.organization;
      final changed = {for (final record in saved.records) record.id: record};
      _records = _records
          .map((record) => changed[record.id] ?? record)
          .toList(growable: false);
      _emitReady();
    } on VaultFailure catch (failure) {
      if (_isCurrent(generation)) {
        _emitFailure(failure.code, retainValues: true);
      }
    } on Object {
      if (_isCurrent(generation)) {
        _emitFailure(VaultFailureCode.internalFailure, retainValues: true);
      }
    }
  }

  void onLock() {
    _generation++;
    _organization = null;
    _records = const [];
    _persisted = false;
    _emit(
      const VaultOrganizationState(
        status: VaultOrganizationStatus.locked,
        folders: [],
        tags: [],
      ),
    );
  }

  VaultOrganization _requireOrganization() =>
      _organization ??
      (throw const VaultFailure(VaultFailureCode.sessionLocked));

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _emitReady() {
    final organization = _requireOrganization();
    _emit(
      VaultOrganizationState(
        status: organization.folders.isEmpty && organization.tags.isEmpty
            ? VaultOrganizationStatus.empty
            : VaultOrganizationStatus.ready,
        folders: List.unmodifiable(organization.folders),
        tags: List.unmodifiable(organization.tags),
      ),
    );
  }

  void _emitFailure(VaultFailureCode code, {bool retainValues = false}) {
    _emit(
      VaultOrganizationState(
        status: switch (code) {
          VaultFailureCode.sessionLocked => VaultOrganizationStatus.locked,
          VaultFailureCode.readOnly => VaultOrganizationStatus.readOnly,
          _ => VaultOrganizationStatus.recoverableFailure,
        },
        folders: retainValues ? _state.folders : const [],
        tags: retainValues ? _state.tags : const [],
        failure: true,
      ),
    );
  }

  void _emit(VaultOrganizationState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _records = const [];
    _organization = null;
    super.dispose();
  }
}

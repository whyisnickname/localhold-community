// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

enum VaultListStatus {
  initial,
  loading,
  ready,
  empty,
  recoverableFailure,
  readOnly,
  locked,
}

enum VaultListLayout { compact, comfortable, grid }

enum VaultListIssue { authorizationDenied, storageFailure, exportFailure }

@immutable
final class VaultListPreferences {
  const VaultListPreferences({
    this.layout = VaultListLayout.compact,
    this.sort = VaultRecordSort.updatedNewest,
  });

  final VaultListLayout layout;
  final VaultRecordSort sort;

  VaultListPreferences copyWith({
    VaultListLayout? layout,
    VaultRecordSort? sort,
  }) => VaultListPreferences(
    layout: layout ?? this.layout,
    sort: sort ?? this.sort,
  );
}

abstract interface class VaultListPreferencesPort {
  Future<VaultListPreferences> read();
  Future<void> write(VaultListPreferences preferences);
}

final class MemoryVaultListPreferencesPort implements VaultListPreferencesPort {
  VaultListPreferences _value = const VaultListPreferences();

  @override
  Future<VaultListPreferences> read() async => _value;

  @override
  Future<void> write(VaultListPreferences preferences) async {
    _value = preferences;
  }
}

final class VaultListLoadData {
  VaultListLoadData({
    required Iterable<VaultRecord> records,
    required this.organization,
  }) : records = List.unmodifiable(records);

  final List<VaultRecord> records;
  final VaultOrganization organization;
}

abstract interface class VaultListDataPort {
  Future<VaultListLoadData> load();

  Future<List<VaultRecord>> applyBulk({
    required List<VaultRecord> records,
    required BulkRecordCommand command,
    required VaultOrganization organization,
    required DateTime now,
  });

  Future<VaultRecord> savePinned({
    required VaultRecord record,
    required bool pinned,
    required DateTime now,
  });

  Future<VaultRecord> restore({
    required VaultRecord record,
    required DateTime now,
  });

  Future<bool> reauthenticateProtectedSearch();

  Future<void> requestPortabilityExport(Set<RecordId> recordIds);
}

@immutable
final class VaultListState {
  VaultListState({
    required this.status,
    required Iterable<SafeRecordProjection> items,
    required this.query,
    required this.filter,
    required this.preferences,
    required this.protectedSearch,
    required Iterable<RecordId> selectedIds,
    required Iterable<VaultFolder> folders,
    required Iterable<VaultTag> tags,
    this.issue,
  }) : items = List.unmodifiable(items),
       selectedIds = Set.unmodifiable(selectedIds),
       folders = List.unmodifiable(folders),
       tags = List.unmodifiable(tags);

  factory VaultListState.initial() => VaultListState(
    status: VaultListStatus.initial,
    items: const [],
    query: '',
    filter: const VaultSearchFilter(lifecycle: RecordLifecycle.active),
    preferences: const VaultListPreferences(),
    protectedSearch: false,
    selectedIds: const {},
    folders: const [],
    tags: const [],
  );

  final VaultListStatus status;
  final List<SafeRecordProjection> items;
  final String query;
  final VaultSearchFilter filter;
  final VaultListPreferences preferences;
  final bool protectedSearch;
  final Set<RecordId> selectedIds;
  final List<VaultFolder> folders;
  final List<VaultTag> tags;
  final VaultListIssue? issue;

  VaultListState copyWith({
    VaultListStatus? status,
    Iterable<SafeRecordProjection>? items,
    String? query,
    VaultSearchFilter? filter,
    VaultListPreferences? preferences,
    bool? protectedSearch,
    Iterable<RecordId>? selectedIds,
    Iterable<VaultFolder>? folders,
    Iterable<VaultTag>? tags,
    VaultListIssue? issue,
    bool clearIssue = false,
  }) => VaultListState(
    status: status ?? this.status,
    items: items ?? this.items,
    query: query ?? this.query,
    filter: filter ?? this.filter,
    preferences: preferences ?? this.preferences,
    protectedSearch: protectedSearch ?? this.protectedSearch,
    selectedIds: selectedIds ?? this.selectedIds,
    folders: folders ?? this.folders,
    tags: tags ?? this.tags,
    issue: clearIssue ? null : (issue ?? this.issue),
  );
}

final class VaultListController extends ChangeNotifier {
  VaultListController({
    required VaultListDataPort data,
    required VaultListPreferencesPort preferences,
    Iterable<RecordTypeDefinition>? definitions,
    this.debounce = const Duration(milliseconds: 275),
  }) : assert(
         debounce >= const Duration(milliseconds: 250) &&
             debounce <= const Duration(milliseconds: 300),
       ),
       _data = data,
       _preferences = preferences,
       _builder = SafeRecordProjectionBuilder(
         definitions: definitions ?? BuiltInTemplateCatalog.all,
       );

  final VaultListDataPort _data;
  final VaultListPreferencesPort _preferences;
  final SafeRecordProjectionBuilder _builder;
  final Duration debounce;
  VaultSearchIndex? _index;
  List<VaultRecord> _records = const [];
  VaultOrganization? _organization;
  Timer? _timer;
  bool _disposed = false;
  int _generation = 0;
  VaultListState _state = VaultListState.initial();

  VaultListState get state => _state;

  Future<void> load() async {
    final generation = ++_generation;
    _emit(_state.copyWith(status: VaultListStatus.loading, clearIssue: true));
    try {
      final values = await Future.wait<Object>([
        _data.load(),
        _preferences.read(),
      ]);
      final loaded = values[0] as VaultListLoadData;
      final preferences = values[1] as VaultListPreferences;
      if (_disposed || generation != _generation) return;
      _records = loaded.records;
      _organization = loaded.organization;
      _rebuildIndex();
      _state = _state.copyWith(
        preferences: preferences,
        folders: loaded.organization.folders,
        tags: loaded.organization.tags,
      );
      _refresh();
    } on VaultFailure catch (failure) {
      if (_disposed || generation != _generation) return;
      _emit(
        _state.copyWith(
          status: switch (failure.code) {
            VaultFailureCode.sessionLocked => VaultListStatus.locked,
            VaultFailureCode.readOnly => VaultListStatus.readOnly,
            _ => VaultListStatus.recoverableFailure,
          },
          items: const [],
          issue: VaultListIssue.storageFailure,
        ),
      );
    } on Object {
      if (_disposed || generation != _generation) return;
      _emit(
        _state.copyWith(
          status: VaultListStatus.recoverableFailure,
          items: const [],
          issue: VaultListIssue.storageFailure,
        ),
      );
    }
  }

  void setQuery(String query) {
    _timer?.cancel();
    _emit(_state.copyWith(query: query, clearIssue: true));
    _timer = Timer(debounce, _refresh);
  }

  void setFilter(VaultSearchFilter filter) {
    _emit(_state.copyWith(filter: filter, selectedIds: const {}));
    _refresh();
  }

  void setFolderFilter(FolderId? folderId) {
    setFilter(
      _copyFilter(
        _state.filter,
        folderId: folderId?.value,
        clearFolder: folderId == null,
      ),
    );
  }

  void toggleTagFilter(TagId tagId) {
    final tags = {..._state.filter.requiredTagIds};
    tags.contains(tagId.value)
        ? tags.remove(tagId.value)
        : tags.add(tagId.value);
    setFilter(_copyFilter(_state.filter, requiredTagIds: tags));
  }

  Future<void> setLayout(VaultListLayout layout) async {
    final next = _state.preferences.copyWith(layout: layout);
    _emit(_state.copyWith(preferences: next));
    try {
      await _preferences.write(next);
    } on Object {
      _emit(_state.copyWith(issue: VaultListIssue.storageFailure));
    }
  }

  Future<void> setSort(VaultRecordSort sort) async {
    final next = _state.preferences.copyWith(sort: sort);
    _emit(
      _state.copyWith(
        preferences: next,
        filter: _copyFilter(_state.filter, sort: sort),
      ),
    );
    _refresh();
    try {
      await _preferences.write(next);
    } on Object {
      _emit(_state.copyWith(issue: VaultListIssue.storageFailure));
    }
  }

  Future<bool> enableProtectedSearch() async {
    if (_state.protectedSearch) return true;
    final generation = _generation;
    late final bool authorized;
    try {
      authorized = await _data.reauthenticateProtectedSearch();
    } on Object {
      if (!_disposed && generation == _generation) {
        _emit(_state.copyWith(issue: VaultListIssue.authorizationDenied));
      }
      return false;
    }
    if (_disposed ||
        generation != _generation ||
        _state.status == VaultListStatus.locked) {
      return false;
    }
    if (!authorized) {
      _emit(_state.copyWith(issue: VaultListIssue.authorizationDenied));
      return false;
    }
    _index?.authorizeProtectedSearch();
    _emit(_state.copyWith(protectedSearch: true, clearIssue: true));
    _refresh();
    return true;
  }

  void disableProtectedSearch({bool clearQuery = false}) {
    _index?.revokeProtectedSearch();
    _emit(
      _state.copyWith(
        protectedSearch: false,
        query: clearQuery ? '' : _state.query,
      ),
    );
    _refresh();
  }

  void toggleSelection(RecordId id) {
    if (!_state.items.any((item) => item.id == id)) return;
    final selected = {..._state.selectedIds};
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    _emit(_state.copyWith(selectedIds: selected));
  }

  void clearSelection() => _emit(_state.copyWith(selectedIds: const {}));

  Future<void> applyBulk(
    BulkRecordCommand command, {
    required DateTime now,
  }) async {
    final selected = _records
        .where((record) => _state.selectedIds.contains(record.id))
        .toList(growable: false);
    if (selected.isEmpty || _organization == null) return;
    final generation = _generation;
    try {
      final saved = await _data.applyBulk(
        records: selected,
        command: command,
        organization: _organization!,
        now: now,
      );
      if (_disposed || generation != _generation) return;
      _mergeSaved(saved);
      clearSelection();
      _refresh();
    } on Object {
      if (_disposed || generation != _generation) return;
      _emit(_state.copyWith(issue: VaultListIssue.storageFailure));
    }
  }

  Future<void> togglePinned(RecordId id, {required DateTime now}) async {
    final record = _records.where((value) => value.id == id).firstOrNull;
    if (record == null) return;
    final generation = _generation;
    try {
      final saved = await _data.savePinned(
        record: record,
        pinned: !record.pinned,
        now: now,
      );
      if (_disposed || generation != _generation) return;
      _mergeSaved([saved]);
      _refresh();
    } on Object {
      if (_disposed || generation != _generation) return;
      _emit(_state.copyWith(issue: VaultListIssue.storageFailure));
    }
  }

  Future<void> restore(RecordId id, {required DateTime now}) async {
    final record = _records.where((value) => value.id == id).firstOrNull;
    if (record == null || record.lifecycle == RecordLifecycle.active) return;
    final generation = _generation;
    try {
      final saved = await _data.restore(record: record, now: now);
      if (_disposed || generation != _generation) return;
      _mergeSaved([saved]);
      _refresh();
    } on Object {
      if (_disposed || generation != _generation) return;
      _emit(_state.copyWith(issue: VaultListIssue.storageFailure));
    }
  }

  Future<void> requestPortabilityExport() async {
    if (_state.selectedIds.isEmpty) return;
    try {
      await _data.requestPortabilityExport(_state.selectedIds);
    } on Object {
      _emit(_state.copyWith(issue: VaultListIssue.exportFailure));
    }
  }

  void onBackgroundOrLock() {
    _generation++;
    _timer?.cancel();
    _index?.destroy();
    _index = null;
    _records = const [];
    _organization = null;
    _emit(VaultListState.initial().copyWith(status: VaultListStatus.locked));
  }

  void _rebuildIndex() {
    _index?.destroy();
    final index = VaultSearchIndex();
    for (final record in _records) {
      index.put(_builder.searchDocument(record, organization: _organization));
    }
    _index = index;
  }

  void _refresh() {
    final index = _index;
    final organization = _organization;
    if (index == null || organization == null) return;
    final filter = _copyFilter(_state.filter, sort: _state.preferences.sort);
    final raw = _state.query.trim().isEmpty
        ? index.browse(filter: filter)
        : index.search(
            _state.query,
            includeProtected: _state.protectedSearch,
            filter: filter,
          );
    final items = raw
        .map((record) => _builder.project(record, organization: organization))
        .toList(growable: false);
    _emit(
      _state.copyWith(
        status: items.isEmpty ? VaultListStatus.empty : VaultListStatus.ready,
        items: items,
        filter: filter,
        clearIssue: true,
      ),
    );
  }

  void _mergeSaved(Iterable<VaultRecord> saved) {
    final byId = {for (final record in saved) record.id: record};
    _records = _records
        .map((record) => byId[record.id] ?? record)
        .toList(growable: false);
    _rebuildIndex();
    if (_state.protectedSearch) _index?.authorizeProtectedSearch();
  }

  VaultSearchFilter _copyFilter(
    VaultSearchFilter source, {
    VaultRecordSort? sort,
    String? folderId,
    bool clearFolder = false,
    Set<String>? requiredTagIds,
  }) => VaultSearchFilter(
    lifecycle: source.lifecycle,
    favoriteOnly: source.favoriteOnly,
    pinnedOnly: source.pinnedOnly,
    folderId: clearFolder ? null : (folderId ?? source.folderId),
    requiredTagIds: requiredTagIds ?? source.requiredTagIds,
    sort: sort ?? source.sort,
  );

  void _emit(VaultListState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _index?.destroy();
    _records = const [];
    _organization = null;
    super.dispose();
  }
}

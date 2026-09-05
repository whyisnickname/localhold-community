// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

enum DuplicateStatus {
  initial,
  loading,
  ready,
  empty,
  merging,
  recoverableFailure,
  readOnly,
  locked,
}

enum DuplicateIssue { authorizationDenied, storageFailure, invalidMerge }

final class LocalDuplicateLoadData {
  LocalDuplicateLoadData({
    required Iterable<VaultRecord> records,
    required this.organization,
  }) : records = List.unmodifiable(records);

  final List<VaultRecord> records;
  final VaultOrganization organization;
}

abstract interface class LocalDuplicateDataPort {
  Future<LocalDuplicateLoadData> load();

  Future<bool> reauthenticateProtectedComparison();

  Future<RecordMergeResult> merge({
    required RecordMergeCommand command,
    required DateTime now,
  });
}

@immutable
final class LocalDuplicateCandidateView {
  LocalDuplicateCandidateView({
    required this.first,
    required this.second,
    required Iterable<DuplicateMatchReason> reasons,
    required this.confidence,
  }) : reasons = Set.unmodifiable(reasons);

  final SafeRecordProjection first;
  final SafeRecordProjection second;
  final Set<DuplicateMatchReason> reasons;
  final DuplicateConfidence confidence;

  @override
  String toString() =>
      'LocalDuplicateCandidateView(${first.id.value}, ${second.id.value}, '
      '${reasons.map((reason) => reason.name).join(',')}, ${confidence.name})';
}

@immutable
final class LocalMergeFieldView {
  const LocalMergeFieldView({
    required this.id,
    required this.definitionId,
    required this.label,
    required this.protected,
    required this.targetAvailable,
    required this.sourceAvailable,
    required this.targetValue,
    required this.sourceValue,
    required this.choice,
  });

  static const mask = '••••••';
  static const empty = '—';

  final String id;
  final String? definitionId;
  final String label;
  final bool protected;
  final bool targetAvailable;
  final bool sourceAvailable;
  final String targetValue;
  final String sourceValue;
  final MergeFieldChoice? choice;

  LocalMergeFieldView copyWith({MergeFieldChoice? choice}) =>
      LocalMergeFieldView(
        id: id,
        definitionId: definitionId,
        label: label,
        protected: protected,
        targetAvailable: targetAvailable,
        sourceAvailable: sourceAvailable,
        targetValue: targetValue,
        sourceValue: sourceValue,
        choice: choice ?? this.choice,
      );

  @override
  String toString() =>
      'LocalMergeFieldView($id, protected: $protected, choice: $choice)';
}

@immutable
final class LocalMergeView {
  LocalMergeView({
    required this.target,
    required this.source,
    required Iterable<LocalMergeFieldView> fields,
  }) : fields = List.unmodifiable(fields);

  final SafeRecordProjection target;
  final SafeRecordProjection source;
  final List<LocalMergeFieldView> fields;

  @override
  String toString() =>
      'LocalMergeView(${target.id.value}, ${source.id.value}, '
      '${fields.map((field) => field.toString()).join(',')})';
}

@immutable
final class LocalDuplicateState {
  LocalDuplicateState({
    required this.status,
    required Iterable<LocalDuplicateCandidateView> candidates,
    required this.protectedComparison,
    this.merge,
    this.issue,
  }) : candidates = List.unmodifiable(candidates);

  factory LocalDuplicateState.initial() => LocalDuplicateState(
    status: DuplicateStatus.initial,
    candidates: const [],
    protectedComparison: false,
  );

  final DuplicateStatus status;
  final List<LocalDuplicateCandidateView> candidates;
  final bool protectedComparison;
  final LocalMergeView? merge;
  final DuplicateIssue? issue;

  LocalDuplicateState copyWith({
    DuplicateStatus? status,
    Iterable<LocalDuplicateCandidateView>? candidates,
    bool? protectedComparison,
    LocalMergeView? merge,
    DuplicateIssue? issue,
    bool clearMerge = false,
    bool clearIssue = false,
  }) => LocalDuplicateState(
    status: status ?? this.status,
    candidates: candidates ?? this.candidates,
    protectedComparison: protectedComparison ?? this.protectedComparison,
    merge: clearMerge ? null : (merge ?? this.merge),
    issue: clearIssue ? null : (issue ?? this.issue),
  );
}

final class LocalDuplicateController extends ChangeNotifier {
  LocalDuplicateController({
    required LocalDuplicateDataPort data,
    Iterable<RecordTypeDefinition>? definitions,
  }) : _data = data,
       _definitions = List.unmodifiable(
         definitions ?? BuiltInTemplateCatalog.all,
       ) {
    _detector = DuplicateDetector(definitions: _definitions);
    _planner = RecordMergePlanner(definitions: _definitions);
    _projection = SafeRecordProjectionBuilder(definitions: _definitions);
  }

  final LocalDuplicateDataPort _data;
  final List<RecordTypeDefinition> _definitions;
  late final DuplicateDetector _detector;
  late final RecordMergePlanner _planner;
  late final SafeRecordProjectionBuilder _projection;
  List<VaultRecord> _records = const [];
  VaultOrganization? _organization;
  RecordMergePreview? _preview;
  bool _disposed = false;
  int _generation = 0;
  LocalDuplicateState _state = LocalDuplicateState.initial();

  LocalDuplicateState get state => _state;

  bool get canCommitMerge {
    final merge = _state.merge;
    return merge != null && merge.fields.every((field) => field.choice != null);
  }

  Future<void> scan() async {
    await _scan(includeProtected: false);
  }

  Future<bool> scanProtected() async {
    final generation = ++_generation;
    _emit(
      _state.copyWith(
        status: DuplicateStatus.loading,
        clearIssue: true,
        clearMerge: true,
      ),
    );
    try {
      final authorized = await _data.reauthenticateProtectedComparison();
      if (!_isCurrent(generation) || !authorized) {
        if (_isCurrent(generation)) {
          _emit(
            _state.copyWith(
              status: _state.candidates.isEmpty
                  ? DuplicateStatus.empty
                  : DuplicateStatus.ready,
              protectedComparison: false,
              issue: DuplicateIssue.authorizationDenied,
            ),
          );
        }
        return false;
      }
      return await _loadAndPublish(
        generation: generation,
        includeProtected: true,
      );
    } on Object {
      if (_isCurrent(generation)) _emitFailure(DuplicateIssue.storageFailure);
      return false;
    }
  }

  /// Advisory hook for an editor. Its result never commits or blocks a save.
  Future<List<LocalDuplicateCandidateView>> advisoryBeforeSave(
    VaultRecord proposed,
  ) async {
    try {
      final loaded = await _data.load();
      final records = [
        ...loaded.records.where((record) => record.id != proposed.id),
        proposed,
      ];
      return _candidateViews(
            _detector.scan(records),
            records,
            loaded.organization,
          )
          .where((candidate) {
            return candidate.first.id == proposed.id ||
                candidate.second.id == proposed.id;
          })
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  void prepareMerge(
    RecordId firstId,
    RecordId secondId, {
    required RecordId targetId,
  }) {
    try {
      final first = _record(firstId);
      final second = _record(secondId);
      if (targetId != firstId && targetId != secondId) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      final target = targetId == firstId ? first : second;
      final source = targetId == firstId ? second : first;
      final preview = _planner.prepare(target: target, source: source);
      _preview = preview;
      final organization = _organization ?? VaultOrganization.empty();
      final fields = preview.slots.map((slot) {
        final targetAvailable = slot.targetField != null;
        final sourceAvailable = slot.sourceField != null;
        return LocalMergeFieldView(
          id: slot.id,
          definitionId:
              slot.targetField?.definitionId ?? slot.sourceField?.definitionId,
          label: slot.label,
          protected: slot.protected,
          targetAvailable: targetAvailable,
          sourceAvailable: sourceAvailable,
          targetValue: _display(slot.targetField, slot.protected),
          sourceValue: _display(slot.sourceField, slot.protected),
          choice: targetAvailable && !sourceAvailable
              ? MergeFieldChoice.target
              : sourceAvailable && !targetAvailable
              ? MergeFieldChoice.source
              : null,
        );
      });
      _emit(
        _state.copyWith(
          merge: LocalMergeView(
            target: _projection.project(target, organization: organization),
            source: _projection.project(source, organization: organization),
            fields: fields,
          ),
          clearIssue: true,
        ),
      );
    } on Object {
      _preview = null;
      _emit(_state.copyWith(issue: DuplicateIssue.invalidMerge));
    }
  }

  void choose(String slotId, MergeFieldChoice choice) {
    final merge = _state.merge;
    if (merge == null) return;
    final field = merge.fields.where((value) => value.id == slotId).firstOrNull;
    if (field == null ||
        (choice == MergeFieldChoice.target && !field.targetAvailable) ||
        (choice == MergeFieldChoice.source && !field.sourceAvailable)) {
      _emit(_state.copyWith(issue: DuplicateIssue.invalidMerge));
      return;
    }
    _emit(
      _state.copyWith(
        merge: LocalMergeView(
          target: merge.target,
          source: merge.source,
          fields: merge.fields
              .map(
                (value) =>
                    value.id == slotId ? value.copyWith(choice: choice) : value,
              )
              .toList(growable: false),
        ),
        clearIssue: true,
      ),
    );
  }

  Future<bool> commitMerge({required DateTime now}) async {
    final preview = _preview;
    final merge = _state.merge;
    if (preview == null || merge == null || !canCommitMerge) {
      _emit(_state.copyWith(issue: DuplicateIssue.invalidMerge));
      return false;
    }
    final generation = _generation;
    _emit(_state.copyWith(status: DuplicateStatus.merging, clearIssue: true));
    try {
      final result = await _data.merge(
        command: RecordMergeCommand(
          targetId: preview.target.id,
          sourceId: preview.source.id,
          expectedTargetRevision: preview.target.revision,
          expectedSourceRevision: preview.source.revision,
          choices: {for (final field in merge.fields) field.id: field.choice!},
        ),
        now: now,
      );
      if (!_isCurrent(generation)) return false;
      final changed = {
        result.target.id: result.target,
        result.source.id: result.source,
      };
      _records = _records
          .map((record) => changed[record.id] ?? record)
          .toList(growable: false);
      _preview = null;
      _publishCandidates(
        includeProtected: _state.protectedComparison,
        clearMerge: true,
      );
      return true;
    } on VaultFailure catch (failure) {
      if (_isCurrent(generation)) {
        _emitFailure(
          failure.code == VaultFailureCode.readOnly
              ? DuplicateIssue.storageFailure
              : DuplicateIssue.storageFailure,
          readOnly: failure.code == VaultFailureCode.readOnly,
          retainMerge: true,
        );
      }
      return false;
    } on Object {
      if (_isCurrent(generation)) {
        _emitFailure(DuplicateIssue.storageFailure, retainMerge: true);
      }
      return false;
    }
  }

  void cancelMerge() {
    _preview = null;
    _emit(_state.copyWith(clearMerge: true, clearIssue: true));
  }

  void onBackgroundOrLock() {
    _generation++;
    _records = const [];
    _organization = null;
    _preview = null;
    _emit(
      LocalDuplicateState(
        status: DuplicateStatus.locked,
        candidates: const [],
        protectedComparison: false,
      ),
    );
  }

  Future<void> _scan({required bool includeProtected}) async {
    final generation = ++_generation;
    _emit(
      _state.copyWith(
        status: DuplicateStatus.loading,
        protectedComparison: includeProtected,
        clearIssue: true,
        clearMerge: true,
      ),
    );
    try {
      await _loadAndPublish(
        generation: generation,
        includeProtected: includeProtected,
      );
    } on Object {
      if (_isCurrent(generation)) _emitFailure(DuplicateIssue.storageFailure);
    }
  }

  Future<bool> _loadAndPublish({
    required int generation,
    required bool includeProtected,
  }) async {
    final loaded = await _data.load();
    if (!_isCurrent(generation)) return false;
    _records = loaded.records;
    _organization = loaded.organization;
    _publishCandidates(includeProtected: includeProtected, clearMerge: true);
    return true;
  }

  void _publishCandidates({
    required bool includeProtected,
    required bool clearMerge,
  }) {
    final candidates = _candidateViews(
      _detector.scan(_records, includeProtectedExactMatches: includeProtected),
      _records,
      _organization ?? VaultOrganization.empty(),
    );
    _emit(
      _state.copyWith(
        status: candidates.isEmpty
            ? DuplicateStatus.empty
            : DuplicateStatus.ready,
        candidates: candidates,
        protectedComparison: includeProtected,
        clearMerge: clearMerge,
        clearIssue: true,
      ),
    );
  }

  List<LocalDuplicateCandidateView> _candidateViews(
    Iterable<DuplicateCandidate> candidates,
    Iterable<VaultRecord> records,
    VaultOrganization organization,
  ) {
    final byId = {for (final record in records) record.id.value: record};
    return candidates
        .map((candidate) {
          final first = byId[candidate.firstId.value]!;
          final second = byId[candidate.secondId.value]!;
          return LocalDuplicateCandidateView(
            first: _projection.project(first, organization: organization),
            second: _projection.project(second, organization: organization),
            reasons: candidate.reasons,
            confidence: candidate.confidence,
          );
        })
        .toList(growable: false);
  }

  VaultRecord _record(RecordId id) =>
      _records.where((record) => record.id == id).firstOrNull ??
      (throw const VaultFailure(VaultFailureCode.objectNotFound));

  String _display(VaultField? field, bool protected) {
    if (field == null || !field.hasUserValue) return LocalMergeFieldView.empty;
    if (protected) return LocalMergeFieldView.mask;
    final value = field.value;
    final text = switch (value) {
      final String value => value,
      final num value => value.toString(),
      final bool value => value.toString(),
      _ => LocalMergeFieldView.empty,
    };
    final clean = text.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ').trim();
    return clean.length > 256 ? '${clean.substring(0, 256)}…' : clean;
  }

  void _emitFailure(
    DuplicateIssue issue, {
    bool readOnly = false,
    bool retainMerge = false,
  }) {
    _emit(
      _state.copyWith(
        status: readOnly
            ? DuplicateStatus.readOnly
            : DuplicateStatus.recoverableFailure,
        issue: issue,
        clearMerge: !retainMerge,
      ),
    );
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _emit(LocalDuplicateState state) {
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
    _preview = null;
    super.dispose();
  }
}

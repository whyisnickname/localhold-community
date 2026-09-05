// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';
import 'search.dart';

enum DuplicateMatchReason {
  title,
  domain,
  username,
  email,
  identifier,
  protectedExactValue,
  conflictCopy,
}

enum DuplicateConfidence { possible, likely, conflictCopy }

final class DuplicateCandidate {
  DuplicateCandidate({
    required this.firstId,
    required this.secondId,
    required Iterable<DuplicateMatchReason> reasons,
    required this.confidence,
  }) : reasons = Set.unmodifiable(reasons);

  final RecordId firstId;
  final RecordId secondId;
  final Set<DuplicateMatchReason> reasons;
  final DuplicateConfidence confidence;

  @override
  String toString() =>
      'DuplicateCandidate(${firstId.value}, ${secondId.value}, '
      '${reasons.map((reason) => reason.name).join(',')}, ${confidence.name})';
}

/// Builds a short-lived, local-only set of duplicate candidates.
///
/// Match values never leave this method. The returned model contains only
/// record identifiers and reviewed reason enums.
final class DuplicateDetector {
  DuplicateDetector({
    required Iterable<RecordTypeDefinition> definitions,
    this._normalizer = const UnicodeSearchNormalizer(),
    this.maximumCandidates = 1000,
    this.maximumBucketMembers = 100,
  }) : _definitions = {
         for (final definition in definitions) definition.stableId: definition,
       } {
    if (maximumCandidates < 1 || maximumBucketMembers < 2) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final Map<String, RecordTypeDefinition> _definitions;
  final SearchNormalizer _normalizer;
  final int maximumCandidates;
  final int maximumBucketMembers;

  List<DuplicateCandidate> scan(
    Iterable<VaultRecord> records, {
    bool includeProtectedExactMatches = false,
  }) {
    final source = records
        .where((record) => record.lifecycle != RecordLifecycle.trashed)
        .toList(growable: false);
    final reasonsByPair = <String, Set<DuplicateMatchReason>>{};
    final idsByPair = <String, (RecordId, RecordId)>{};
    final buckets =
        <(String, DuplicateMatchReason, String, String), List<RecordId>>{};
    final byId = {for (final record in source) record.id.value: record};

    // Conflict relationships are explicit and must not be displaced by a
    // large ordinary feature bucket.
    for (final record in source) {
      final original = record.conflictOf;
      if (original == null || !byId.containsKey(original.value)) continue;
      final other = byId[original.value]!;
      if (other.typeId != record.typeId) continue;
      _addReason(
        reasonsByPair,
        idsByPair,
        record.id,
        original,
        DuplicateMatchReason.conflictCopy,
      );
    }

    for (final record in source) {
      final definition = _definitions[record.typeId];
      if (definition == null) continue;
      final definitionsById = {
        for (final field in definition.fields) field.stableId: field,
      };
      for (final field in record.fields) {
        if (!field.hasUserValue) continue;
        final fieldDefinition = definitionsById[field.definitionId];
        if (fieldDefinition == null) continue;
        final protected =
            fieldDefinition.protected ||
            field.kind == VaultFieldKind.secret ||
            field.kind == VaultFieldKind.totp ||
            field.kind == VaultFieldKind.attachment;
        if (protected) {
          if (includeProtectedExactMatches) {
            final exact = _protectedExact(field.value);
            if (exact != null) {
              _addBucket(buckets, (
                record.typeId,
                DuplicateMatchReason.protectedExactValue,
                fieldDefinition.stableId,
                exact,
              ), record.id);
            }
          }
          continue;
        }
        final feature = _safeFeature(field, fieldDefinition);
        if (feature == null) continue;
        _addBucket(buckets, (
          record.typeId,
          feature.$1,
          fieldDefinition.stableId,
          feature.$2,
        ), record.id);
      }
    }

    for (final entry in buckets.entries) {
      final ids = entry.value.toSet().toList()..sort(_compareRecordId);
      if (ids.length < 2) continue;
      final reason = entry.key.$2;
      for (var first = 0; first < ids.length - 1; first++) {
        for (var second = first + 1; second < ids.length; second++) {
          _addReason(reasonsByPair, idsByPair, ids[first], ids[second], reason);
        }
      }
    }

    final candidates =
        reasonsByPair.entries
            .map((entry) {
              final pair = idsByPair[entry.key]!;
              final reasons = entry.value;
              final confidence =
                  reasons.contains(DuplicateMatchReason.conflictCopy)
                  ? DuplicateConfidence.conflictCopy
                  : reasons.contains(
                          DuplicateMatchReason.protectedExactValue,
                        ) ||
                        reasons.contains(DuplicateMatchReason.identifier) ||
                        reasons.length >= 2
                  ? DuplicateConfidence.likely
                  : DuplicateConfidence.possible;
              return DuplicateCandidate(
                firstId: pair.$1,
                secondId: pair.$2,
                reasons: reasons,
                confidence: confidence,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final first = _compareRecordId(a.firstId, b.firstId);
            return first != 0
                ? first
                : _compareRecordId(a.secondId, b.secondId);
          });
    buckets.clear();
    return List.unmodifiable(candidates);
  }

  (DuplicateMatchReason, String)? _safeFeature(
    VaultField field,
    FieldDefinition definition,
  ) {
    final value = field.value;
    if (value is! String) return null;
    final normalized = switch (field.kind) {
      VaultFieldKind.url => _domain(value),
      _ => _normalizer.normalize(value),
    };
    if (normalized == null || !_isUseful(normalized)) return null;
    if (definition.stableId == 'title') {
      return (DuplicateMatchReason.title, normalized);
    }
    return switch (field.kind) {
      VaultFieldKind.url => (DuplicateMatchReason.domain, normalized),
      VaultFieldKind.username => (DuplicateMatchReason.username, normalized),
      VaultFieldKind.email => (DuplicateMatchReason.email, normalized),
      _ when _isIdentifier(definition.stableId) => (
        DuplicateMatchReason.identifier,
        normalized,
      ),
      _ => null,
    };
  }

  String? _domain(String value) {
    final candidate = value.contains('://') ? value : 'https://$value';
    final host = Uri.tryParse(candidate)?.host.toLowerCase();
    if (host == null || host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  String? _protectedExact(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is num || value is bool) return value.toString();
    return null;
  }

  bool _isIdentifier(String id) =>
      id == 'fingerprint' ||
      id == 'player_id' ||
      id == 'public_address' ||
      id.endsWith('_id');

  bool _isUseful(String value) {
    if (value.length < 3) return false;
    return !const <String>{
      'account',
      'email',
      'login',
      'record',
      'test',
      'аккаунт',
      'почта',
      'логин',
      'запись',
      'тест',
    }.contains(value);
  }

  void _addBucket(
    Map<(String, DuplicateMatchReason, String, String), List<RecordId>> buckets,
    (String, DuplicateMatchReason, String, String) key,
    RecordId id,
  ) {
    final bucket = buckets.putIfAbsent(key, () => []);
    if (bucket.length < maximumBucketMembers) bucket.add(id);
  }

  void _addReason(
    Map<String, Set<DuplicateMatchReason>> reasons,
    Map<String, (RecordId, RecordId)> ids,
    RecordId left,
    RecordId right,
    DuplicateMatchReason reason,
  ) {
    final pair = _compareRecordId(left, right) <= 0
        ? (left, right)
        : (right, left);
    final key = '${pair.$1.value}|${pair.$2.value}';
    if (!reasons.containsKey(key) && reasons.length >= maximumCandidates) {
      return;
    }
    ids[key] = pair;
    reasons.putIfAbsent(key, () => {}).add(reason);
  }

  int _compareRecordId(RecordId a, RecordId b) => a.value.compareTo(b.value);
}

enum MergeFieldChoice { target, source }

final class RecordMergeFieldSlot {
  const RecordMergeFieldSlot({
    required this.id,
    required this.label,
    required this.protected,
    required this.targetField,
    required this.sourceField,
  });

  final String id;
  final String label;
  final bool protected;
  final VaultField? targetField;
  final VaultField? sourceField;
}

final class RecordMergePreview {
  RecordMergePreview({
    required this.target,
    required this.source,
    required Iterable<RecordMergeFieldSlot> slots,
  }) : slots = List.unmodifiable(slots);

  final VaultRecord target;
  final VaultRecord source;
  final List<RecordMergeFieldSlot> slots;
}

final class RecordMergePair {
  const RecordMergePair({required this.target, required this.source});

  final VaultRecord target;
  final VaultRecord source;
}

final class RecordMergeCommand {
  RecordMergeCommand({
    required this.targetId,
    required this.sourceId,
    required this.expectedTargetRevision,
    required this.expectedSourceRevision,
    required Map<String, MergeFieldChoice> choices,
  }) : choices = Map.unmodifiable(choices) {
    if (targetId == sourceId ||
        expectedTargetRevision < 1 ||
        expectedSourceRevision < 1 ||
        this.choices.isEmpty) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final RecordId targetId;
  final RecordId sourceId;
  final int expectedTargetRevision;
  final int expectedSourceRevision;
  final Map<String, MergeFieldChoice> choices;
}

final class RecordMergeResult {
  const RecordMergeResult({required this.target, required this.source});

  final VaultRecord target;
  final VaultRecord source;
}

final class RecordMergePlanner {
  RecordMergePlanner({
    required Iterable<RecordTypeDefinition> definitions,
    this._normalizer = const UnicodeSearchNormalizer(),
  }) : _definitions = {
         for (final definition in definitions) definition.stableId: definition,
       };

  final Map<String, RecordTypeDefinition> _definitions;
  final SearchNormalizer _normalizer;

  RecordMergePreview prepare({
    required VaultRecord target,
    required VaultRecord source,
  }) {
    if (target.id == source.id ||
        target.typeId != source.typeId ||
        target.lifecycle == RecordLifecycle.trashed ||
        source.lifecycle == RecordLifecycle.trashed) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final definition = _definitions[target.typeId];
    if (definition == null) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final definitionsById = {
      for (final field in definition.fields) field.stableId: field,
    };
    final targetGroups = _group(target.fields);
    final sourceGroups = _group(source.fields);
    final keys = <String>{...targetGroups.keys, ...sourceGroups.keys}.toList();
    final slots = <RecordMergeFieldSlot>[];
    for (final key in keys) {
      final targetFields = targetGroups[key] ?? const <VaultField>[];
      final sourceFields = sourceGroups[key] ?? const <VaultField>[];
      final count = targetFields.length > sourceFields.length
          ? targetFields.length
          : sourceFields.length;
      for (var index = 0; index < count; index++) {
        final targetField = index < targetFields.length
            ? targetFields[index]
            : null;
        final sourceField = index < sourceFields.length
            ? sourceFields[index]
            : null;
        final field = targetField ?? sourceField!;
        final fieldDefinition = definitionsById[field.definitionId];
        slots.add(
          RecordMergeFieldSlot(
            id: '$key#$index',
            label: fieldDefinition?.defaultLabel ?? field.label,
            protected:
                fieldDefinition == null ||
                fieldDefinition.protected ||
                field.kind == VaultFieldKind.secret ||
                field.kind == VaultFieldKind.totp ||
                field.kind == VaultFieldKind.attachment,
            targetField: targetField,
            sourceField: sourceField,
          ),
        );
      }
    }
    return RecordMergePreview(target: target, source: source, slots: slots);
  }

  RecordMergePair apply({
    required RecordMergePreview preview,
    required Map<String, MergeFieldChoice> choices,
    required DateTime now,
  }) {
    if (choices.length != preview.slots.length ||
        !preview.slots.every((slot) => choices.containsKey(slot.id))) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final fields = <VaultField>[];
    final ids = <String>{};
    for (final slot in preview.slots) {
      final selected = switch (choices[slot.id]!) {
        MergeFieldChoice.target => slot.targetField,
        MergeFieldChoice.source => slot.sourceField,
      };
      if (selected == null) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      var field = selected;
      if (!ids.add(field.id.value)) {
        field = VaultField(
          id: FieldId.generate(),
          kind: field.kind,
          label: field.label,
          value: field.value,
          definitionId: field.definitionId,
          options: field.options,
        );
        ids.add(field.id.value);
      }
      fields.add(field);
    }
    final tags = <TagId>{...preview.target.tagIds, ...preview.source.tagIds};
    final target = preview.target.copyWith(
      fields: fields,
      updatedAt: now.toUtc(),
      favorite: preview.target.favorite || preview.source.favorite,
      pinned: preview.target.pinned || preview.source.pinned,
      tagIds: tags,
      clearConflict: true,
    );
    final source = preview.source.copyWith(
      lifecycle: RecordLifecycle.trashed,
      updatedAt: now.toUtc(),
    );
    return RecordMergePair(target: target, source: source);
  }

  Map<String, List<VaultField>> _group(List<VaultField> fields) {
    final result = <String, List<VaultField>>{};
    for (final field in fields) {
      final key = field.definitionId != null
          ? 'definition:${field.definitionId}'
          : 'custom:${field.kind.name}:${_normalizer.normalize(field.label)}';
      result.putIfAbsent(key, () => []).add(field);
    }
    return result;
  }
}

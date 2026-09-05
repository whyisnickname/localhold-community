// SPDX-License-Identifier: MPL-2.0

import 'identifiers.dart';
import 'models.dart';
import 'organization.dart';
import 'search.dart';

final class SafeRecordProjection {
  const SafeRecordProjection({
    required this.id,
    required this.typeId,
    required this.displayName,
    required this.secondary,
    required this.favorite,
    required this.pinned,
    required this.lifecycle,
    required this.folderId,
    required this.folderName,
    required this.tagIds,
    required this.tagNames,
    required this.createdAt,
    required this.updatedAt,
  });

  final RecordId id;
  final String typeId;
  final String displayName;
  final String? secondary;
  final bool favorite;
  final bool pinned;
  final RecordLifecycle lifecycle;
  final FolderId? folderId;
  final String? folderName;
  final Set<TagId> tagIds;
  final List<String> tagNames;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String toString() =>
      'SafeRecordProjection(${id.value}, $typeId, $displayName, '
      '$secondary, $folderName, ${tagNames.join(',')})';
}

/// Converts unlocked records into the only representation that may cross the
/// list/search presentation boundary.
final class SafeRecordProjectionBuilder {
  SafeRecordProjectionBuilder({
    required Iterable<RecordTypeDefinition> definitions,
  }) : _definitions = {
         for (final definition in definitions) definition.stableId: definition,
       };

  final Map<String, RecordTypeDefinition> _definitions;

  SafeRecordProjection project(
    VaultRecord record, {
    VaultOrganization? organization,
  }) {
    final definition = _definitions[record.typeId];
    final fields = _resolvedFields(record, definition);
    final title = _firstSafeValue(
      fields.where((entry) => entry.definition.stableId == 'title'),
    );
    final fallback = _firstSafeValue(
      fields.where((entry) => entry.definition.displayCandidate),
    );
    final displayName = _clean(
      title ?? fallback ?? definition?.defaultName ?? 'Record',
    );
    String? secondary;
    for (final entry in fields) {
      final value = _safeSecondary(entry.field);
      if (value != null && value != displayName) {
        secondary = value;
        break;
      }
    }
    final folder = organization?.folders
        .where((value) => value.id == record.folderId)
        .firstOrNull;
    final tagsById = {
      for (final tag in organization?.tags ?? const <VaultTag>[])
        tag.id.value: tag,
    };
    final tagNames = record.tagIds
        .map((id) => tagsById[id.value]?.name)
        .whereType<String>()
        .map(_clean)
        .toList(growable: false);
    return SafeRecordProjection(
      id: record.id,
      typeId: record.typeId,
      displayName: displayName,
      secondary: secondary,
      favorite: record.favorite,
      pinned: record.pinned,
      lifecycle: record.lifecycle,
      folderId: record.folderId,
      folderName: folder == null ? null : _clean(folder.name),
      tagIds: Set.unmodifiable(record.tagIds),
      tagNames: List.unmodifiable(tagNames),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  SearchDocument searchDocument(
    VaultRecord record, {
    VaultOrganization? organization,
  }) {
    final definition = _definitions[record.typeId];
    final public = <String>[];
    final protected = <String>[];
    for (final entry in _resolvedFields(record, definition)) {
      final text = _searchText(entry.field);
      if (text == null) continue;
      switch (entry.definition.searchScope) {
        case FieldSearchScope.none:
          break;
        case FieldSearchScope.standard:
          public.add(text);
        case FieldSearchScope.protected:
          protected.add(text);
      }
    }
    if (organization != null) {
      final projection = project(record, organization: organization);
      public.addAll([
        if (projection.folderName case final folder?) folder,
        ...projection.tagNames,
      ]);
    }
    final projection = project(record, organization: organization);
    return SearchDocument(
      record: record,
      publicText: List.unmodifiable(public),
      protectedText: List.unmodifiable(protected),
      safeSortKey: projection.displayName,
    );
  }

  List<_ResolvedField> _resolvedFields(
    VaultRecord record,
    RecordTypeDefinition? definition,
  ) {
    if (definition == null) return const [];
    final byId = {for (final field in definition.fields) field.stableId: field};
    return record.fields
        .map((field) {
          final fieldDefinition = byId[field.definitionId];
          return fieldDefinition == null
              ? null
              : _ResolvedField(field: field, definition: fieldDefinition);
        })
        .whereType<_ResolvedField>()
        .toList(growable: false);
  }

  String? _firstSafeValue(Iterable<_ResolvedField> fields) {
    for (final entry in fields) {
      if (entry.definition.protected || !entry.field.hasUserValue) continue;
      final value = entry.field.value;
      if (value is String && value.trim().isNotEmpty) return _clean(value);
    }
    return null;
  }

  String? _safeSecondary(VaultField field) {
    if (!field.hasUserValue || field.value is! String) return null;
    final value = (field.value! as String).trim();
    return switch (field.kind) {
      VaultFieldKind.username || VaultFieldKind.email => _clean(value),
      VaultFieldKind.url => _normalizedDomain(value),
      _ => null,
    };
  }

  String? _searchText(VaultField field) {
    if (!field.hasUserValue) return null;
    if (field.kind == VaultFieldKind.url && field.value is String) {
      return _normalizedDomain(field.value! as String);
    }
    return switch (field.value) {
      final String value => _clean(value),
      final num value => value.toString(),
      final bool value => value.toString(),
      _ => null,
    };
  }

  String? _normalizedDomain(String value) {
    final candidate = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(candidate);
    final host = uri?.host.toLowerCase();
    if (host == null || host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  String _clean(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ')
        .trim();
    return cleaned.length > 256 ? cleaned.substring(0, 256) : cleaned;
  }
}

final class _ResolvedField {
  const _ResolvedField({required this.field, required this.definition});

  final VaultField field;
  final FieldDefinition definition;
}

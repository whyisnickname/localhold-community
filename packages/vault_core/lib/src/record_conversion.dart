// SPDX-License-Identifier: MPL-2.0

import 'editor_draft.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';

enum ConversionDisposition { mapped, unmapped, incompatible }

final class ConversionFieldPreview {
  const ConversionFieldPreview({
    required this.source,
    required this.disposition,
    this.targetDefinition,
  });

  final VaultField source;
  final ConversionDisposition disposition;
  final FieldDefinition? targetDefinition;
}

final class RecordConversionPreview {
  RecordConversionPreview({
    required this.source,
    required this.target,
    required Iterable<ConversionFieldPreview> fields,
  }) : fields = List.unmodifiable(fields) {
    if (source.typeId == target.stableId ||
        fields.any((field) => !field.source.hasUserValue)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final EditorDraftSnapshot source;
  final RecordTypeDefinition target;
  final List<ConversionFieldPreview> fields;

  int count(ConversionDisposition disposition) =>
      fields.where((field) => field.disposition == disposition).length;

  EditorDraftSnapshot apply({required DateTime now}) {
    var result = EditorDraftSnapshot.fromTemplate(target, now: now);
    final targetFields = [...result.fields];
    final extras = <VaultField>[];
    for (final preview in fields) {
      final targetDefinition = preview.targetDefinition;
      if (preview.disposition == ConversionDisposition.mapped &&
          targetDefinition != null) {
        final index = targetFields.indexWhere(
          (field) => field.definitionId == targetDefinition.stableId,
        );
        if (index < 0) {
          throw const VaultFailure(VaultFailureCode.internalFailure);
        }
        final targetField = targetFields[index];
        targetFields[index] = VaultField(
          id: targetField.id,
          kind: targetField.kind,
          label: targetField.label,
          value: preview.source.value,
          definitionId: targetField.definitionId,
          options: preview.source.options,
        );
      } else {
        extras.add(
          VaultField(
            id: FieldId.generate(),
            kind: preview.source.kind,
            label: preview.source.label,
            value: preview.source.value,
            options: {
              ...preview.source.options,
              'conversionSourceDefinitionId': preview.source.definitionId,
              'conversionDisposition': preview.disposition.name,
            },
          ),
        );
      }
    }
    result = EditorDraftSnapshot(
      recordId: source.recordId,
      typeId: target.stableId,
      fields: [...targetFields, ...extras],
      createdAt: source.createdAt,
    );
    return result;
  }
}

final class RecordConversionPlanner {
  const RecordConversionPlanner();

  RecordConversionPreview preview({
    required EditorDraftSnapshot source,
    required RecordTypeDefinition target,
  }) {
    if (source.typeId == target.stableId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final targetByStableId = {
      for (final definition in target.fields) definition.stableId: definition,
    };
    return RecordConversionPreview(
      source: source,
      target: target,
      fields: source.fields.where((field) => field.hasUserValue).map((field) {
        final targetDefinition = targetByStableId[field.definitionId];
        if (targetDefinition == null) {
          return ConversionFieldPreview(
            source: field,
            disposition: ConversionDisposition.unmapped,
          );
        }
        if (!_compatible(field.kind, targetDefinition.kind)) {
          return ConversionFieldPreview(
            source: field,
            disposition: ConversionDisposition.incompatible,
            targetDefinition: targetDefinition,
          );
        }
        return ConversionFieldPreview(
          source: field,
          disposition: ConversionDisposition.mapped,
          targetDefinition: targetDefinition,
        );
      }),
    );
  }

  bool _compatible(VaultFieldKind source, VaultFieldKind target) {
    if (source == target) return true;
    const textKinds = {
      VaultFieldKind.text,
      VaultFieldKind.username,
      VaultFieldKind.email,
      VaultFieldKind.phone,
      VaultFieldKind.url,
      VaultFieldKind.note,
      VaultFieldKind.address,
    };
    return textKinds.contains(source) && textKinds.contains(target);
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test('conversion classifies and preserves every non-empty source value', () {
    final now = DateTime.utc(2026, 9, 5);
    final sourceTemplate = _template(BuiltInRecordTypes.account);
    var source = EditorDraftSnapshot.fromTemplate(sourceTemplate, now: now);
    source = _set(source, 'title', 'Primary');
    source = _set(source, 'password', 'canary-secret');
    source = _set(source, 'website', 'https://example.test');

    final target = RecordTypeDefinition(
      stableId: 'test.target.v1',
      defaultName: 'Target',
      fields: [
        FieldDefinition(
          stableId: 'title',
          kind: VaultFieldKind.boolean,
          defaultLabel: 'Title toggle',
        ),
        FieldDefinition(
          stableId: 'password',
          kind: VaultFieldKind.secret,
          defaultLabel: 'Password',
          protected: true,
        ),
      ],
    );

    final preview = const RecordConversionPlanner().preview(
      source: source,
      target: target,
    );
    expect(preview.count(ConversionDisposition.mapped), 1);
    expect(preview.count(ConversionDisposition.incompatible), 1);
    expect(preview.count(ConversionDisposition.unmapped), 1);

    final converted = preview.apply(now: now);
    expect(converted.recordId, source.recordId);
    expect(converted.typeId, target.stableId);
    final values = converted.fields
        .where((field) => field.hasUserValue)
        .map((field) => field.value)
        .toList();
    expect(
      values,
      containsAll(['Primary', 'canary-secret', 'https://example.test']),
    );
    expect(
      converted.fields.where((field) => field.definitionId == null),
      hasLength(2),
    );
  });

  test('conversion rejects a no-op target', () {
    final now = DateTime.utc(2026, 9, 5);
    final template = _template(BuiltInRecordTypes.account);
    final source = EditorDraftSnapshot.fromTemplate(template, now: now);
    expect(
      () => const RecordConversionPlanner().preview(
        source: source,
        target: template,
      ),
      throwsA(isA<VaultFailure>()),
    );
  });
}

EditorDraftSnapshot _set(
  EditorDraftSnapshot source,
  String definitionId,
  Object value,
) {
  final field = source.fields.singleWhere(
    (candidate) => candidate.definitionId == definitionId,
  );
  return source.withFieldValue(field.id, value);
}

RecordTypeDefinition _template(String id) =>
    BuiltInTemplateCatalog.all.singleWhere((value) => value.stableId == id);

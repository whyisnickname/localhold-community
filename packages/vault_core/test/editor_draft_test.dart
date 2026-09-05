// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  group('editor draft', () {
    test(
      'persists an all-empty form while record commit stays invalid',
      () async {
        final now = DateTime.utc(2026, 9, 5);
        final template = _template(BuiltInRecordTypes.account);
        final snapshot = EditorDraftSnapshot.fromTemplate(template, now: now);
        expect(snapshot.hasUserValue, isFalse);
        expect(
          () => snapshot.materialize(now: now),
          throwsA(_failure(VaultFailureCode.invalidInput)),
        );

        final repository = _MemoryRepository();
        final service = EncryptedEditorDraftService(
          repository: repository,
          cipher: _PassThroughCipher(),
        );
        final draft = EditorDraftDocument.create(snapshot: snapshot, now: now);
        await service.create(draft);
        final loaded = await service.loadAll();
        expect(loaded.single.id, draft.id);
        expect(
          loaded.single.snapshot.fields,
          hasLength(template.fields.length),
        );
        expect(loaded.single.snapshot.hasUserValue, isFalse);
      },
    );

    test(
      'materializes after one value and uses only safe display candidates',
      () {
        final now = DateTime.utc(2026, 9, 5);
        final template = _template(BuiltInRecordTypes.account);
        var snapshot = EditorDraftSnapshot.fromTemplate(template, now: now);
        final password = snapshot.fields.singleWhere(
          (field) => field.definitionId == 'password',
        );
        snapshot = snapshot.withFieldValue(password.id, 'canary-secret');
        expect(snapshot.safeDisplayName(template), 'Account');

        final title = snapshot.fields.singleWhere(
          (field) => field.definitionId == 'title',
        );
        snapshot = snapshot.withFieldValue(title.id, '  Personal  ');
        expect(snapshot.safeDisplayName(template), 'Personal');
        expect(
          snapshot.materialize(now: now).fields,
          hasLength(template.fields.length),
        );
      },
    );

    test('whitespace is empty for ordinary fields but valid for a secret', () {
      final ordinary = VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.text,
        label: 'Title',
        value: '   ',
      );
      final secret = VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.secret,
        label: 'Secret',
        value: '   ',
      );
      expect(ordinary.hasUserValue, isFalse);
      expect(secret.hasUserValue, isTrue);
    });

    test('non-empty removal asks for confirmation and remains undoable', () {
      final now = DateTime.utc(2026, 9, 5);
      final template = _template(BuiltInRecordTypes.secureNote);
      var snapshot = EditorDraftSnapshot.fromTemplate(template, now: now);
      final emptyPlan = snapshot.planRemoval(snapshot.fields.first.id);
      expect(emptyPlan.requiresConfirmation, isFalse);
      expect(emptyPlan.apply().fields, hasLength(snapshot.fields.length - 1));

      final body = snapshot.fields.singleWhere(
        (field) => field.definitionId == 'body',
      );
      snapshot = snapshot.withFieldValue(body.id, 'Do not lose this');
      final plan = snapshot.planRemoval(body.id);
      expect(plan.requiresConfirmation, isTrue);
      final removed = plan.apply();
      expect(removed.fields.any((field) => field.id == body.id), isFalse);
      final restored = removed.restore(plan.removed);
      expect(restored.fields[plan.removed.index].value, 'Do not lose this');
    });

    test(
      'stale draft replacement creates a separate encrypted conflict copy',
      () async {
        final now = DateTime.utc(2026, 9, 5);
        final repository = _MemoryRepository();
        final service = EncryptedEditorDraftService(
          repository: repository,
          cipher: _PassThroughCipher(),
        );
        final original = EditorDraftDocument.create(
          snapshot: EditorDraftSnapshot.fromTemplate(
            _template(BuiltInRecordTypes.secureNote),
            now: now,
          ),
          now: now,
        );
        await service.create(original);

        final result = await service.replace(
          draft: original,
          expectedRevision: 7,
          now: now.add(const Duration(minutes: 1)),
        );
        expect(result.conflictCopy, isNotNull);
        expect(result.conflictCopy!.id, isNot(original.id));
        expect(repository.values, hasLength(2));
      },
    );

    test('persisted editor envelope does not contain a draft canary', () async {
      final now = DateTime.utc(2026, 9, 5);
      final template = _template(BuiltInRecordTypes.secureNote);
      var snapshot = EditorDraftSnapshot.fromTemplate(template, now: now);
      snapshot = snapshot.withFieldValue(
        snapshot.fields.first.id,
        'EDITOR-DRAFT-CANARY-9f51',
      );
      final repository = _MemoryRepository();
      final service = EncryptedEditorDraftService(
        repository: repository,
        cipher: _XorCipher(),
      );
      await service.create(
        EditorDraftDocument.create(snapshot: snapshot, now: now),
      );
      final envelope = repository.values.values.single.envelope;
      expect(
        utf8.decode(envelope, allowMalformed: true),
        isNot(contains('EDITOR-DRAFT-CANARY-9f51')),
      );
      expect((await service.loadAll()).single.snapshot.hasUserValue, isTrue);
    });
  });
}

RecordTypeDefinition _template(String id) =>
    BuiltInTemplateCatalog.all.singleWhere((value) => value.stableId == id);

final class _PassThroughCipher implements PayloadCipher {
  @override
  String get vaultId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  String get keyGenerationId => 'BBBBBBBBBBBBBBBBBBBBBB';

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async => Uint8List.fromList(envelope);

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async => Uint8List.fromList(plaintext);
}

final class _XorCipher implements PayloadCipher {
  @override
  String get vaultId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  String get keyGenerationId => 'BBBBBBBBBBBBBBBBBBBBBB';

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async => _transform(envelope);

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async => _transform(plaintext);

  Uint8List _transform(Uint8List value) =>
      Uint8List.fromList(value.map((byte) => byte ^ 0xa5).toList());
}

final class _MemoryRepository implements CiphertextRepository {
  final Map<String, EncryptedObject> values = {};

  @override
  Future<void> create(EncryptedObject object) async {
    if (values.containsKey(object.objectId)) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values[object.objectId] = object;
  }

  @override
  Future<void> quarantine({
    required String objectId,
    required int expectedRevision,
    required VaultFailureCode reason,
  }) async => values.remove(objectId);

  @override
  Future<EncryptedObject?> read(String objectId) async => values[objectId];

  @override
  Future<List<EncryptedObject>> readAll() async => List.of(values.values);

  @override
  Future<void> remove({
    required String objectId,
    required int expectedRevision,
  }) async => values.remove(objectId);

  @override
  Future<void> replace({
    required EncryptedObject object,
    required int expectedRevision,
  }) async {
    final current = values[object.objectId];
    if (current == null || current.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values[object.objectId] = object;
  }

  @override
  Stream<List<EncryptedObject>> watchAll() =>
      Stream.value(values.values.toList());
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

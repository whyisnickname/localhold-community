// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test('editor autosaves the latest encrypted draft after idle', () async {
    final port = _EditorPort();
    final controller = _controller(port: port, delay: Duration.zero);
    addTearDown(controller.dispose);
    final title = controller.snapshot.fields.first;
    controller.updateField(title.id, 'Local title');
    await controller.saveDraftNow();

    expect(port.saveCalls, 1);
    expect(controller.persistenceStatus, EditorPersistenceStatus.saved);
    expect(controller.isDirty, isFalse);
    expect(controller.draft.revision, 1);
  });

  test('autosave failure keeps current edits and remains retryable', () async {
    final port = _EditorPort(failSave: true);
    final controller = _controller(port: port);
    addTearDown(controller.dispose);
    final title = controller.snapshot.fields.first;
    controller.updateField(title.id, 'Unsaved edit');

    expect(await controller.saveDraftNow(), isFalse);
    expect(controller.snapshot.fields.first.value, 'Unsaved edit');
    expect(
      controller.persistenceStatus,
      EditorPersistenceStatus.recoverableFailure,
    );
    expect(controller.isDirty, isTrue);
  });

  test('all-empty commit is blocked before the port', () async {
    final port = _EditorPort();
    final controller = _controller(port: port);
    addTearDown(controller.dispose);
    expect(await controller.commit(), isNull);
    expect(port.commitCalls, 0);
  });

  test('removal can be undone and Premium additions are domain-gated', () {
    final port = _EditorPort();
    final controller = _controller(port: port);
    addTearDown(controller.dispose);
    final title = controller.snapshot.fields.first;
    controller.updateField(title.id, 'Value');
    final plan = controller.planRemoval(title.id);
    expect(plan.requiresConfirmation, isTrue);
    controller.applyRemoval(plan);
    expect(
      controller.snapshot.fields.any((field) => field.id == title.id),
      isFalse,
    );
    controller.undoLastRemoval();
    expect(
      controller.snapshot.fields.any((field) => field.id == title.id),
      isTrue,
    );

    expect(
      () =>
          controller.addPremiumField(kind: VaultFieldKind.totp, label: 'TOTP'),
      throwsA(isA<VaultFailure>()),
    );
  });

  test('expired Premium may edit an existing TOTP field', () {
    final now = DateTime.utc(2026, 9, 5);
    final template = _template(BuiltInRecordTypes.account);
    final base = EditorDraftSnapshot.fromTemplate(template, now: now);
    final totp = VaultField(
      id: FieldId.generate(),
      kind: VaultFieldKind.totp,
      label: 'TOTP',
      value: const {'account': 'old'},
    );
    final draft = EditorDraftDocument.create(
      snapshot: base.copyWith(fields: [...base.fields, totp]),
      now: now,
    );
    final controller = RecordEditorController(
      draft: draft,
      template: template,
      port: _EditorPort(),
      creationPolicy: const CommunityFreeVaultCreationPolicy(),
    );
    addTearDown(controller.dispose);
    controller.updateField(totp.id, const {'account': 'new'});
    expect(
      controller.snapshot.fields
          .singleWhere((field) => field.id == totp.id)
          .value,
      const {'account': 'new'},
    );
  });

  test(
    'local adapter commits a persisted draft and keeps only the record',
    () async {
      final now = DateTime.utc(2026, 9, 5);
      final repository = _MemoryRepository();
      final cipher = _PassThroughCipher();
      final drafts = EncryptedEditorDraftService(
        repository: repository,
        cipher: cipher,
      );
      final records = EncryptedRecordService(
        repository: repository,
        cipher: cipher,
        creationPolicy: const _AllowPolicy(),
      );
      final template = _template(BuiltInRecordTypes.secureNote);
      var snapshot = EditorDraftSnapshot.fromTemplate(template, now: now);
      snapshot = snapshot.withFieldValue(snapshot.fields.first.id, 'Saved');
      final draft = EditorDraftDocument.create(snapshot: snapshot, now: now);
      final port = EncryptedRecordEditorPort(records: records, drafts: drafts);

      await port.saveDraft(draft, alreadyPersisted: false, now: now);
      expect(repository.values, hasLength(1));
      final result = await port.commit(
        draft,
        now: now,
        draftWasPersisted: true,
      );
      expect(result.record, isNotNull);
      expect(repository.values, hasLength(1));
      expect(await records.read(snapshot.recordId), isNotNull);
    },
  );

  test('disposing during an in-flight autosave is safe', () async {
    final port = _DelayedPort();
    final controller = _controller(port: port);
    controller.updateField(controller.snapshot.fields.first.id, 'Value');
    final save = controller.saveDraftNow();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    port.release.complete();
    expect(await save, isTrue);
  });
}

RecordEditorController _controller({
  required RecordEditorPort port,
  Duration delay = const Duration(days: 1),
}) {
  final now = DateTime.utc(2026, 9, 5);
  final template = _template(BuiltInRecordTypes.secureNote);
  return RecordEditorController(
    draft: EditorDraftDocument.create(
      snapshot: EditorDraftSnapshot.fromTemplate(template, now: now),
      now: now,
    ),
    template: template,
    port: port,
    creationPolicy: const CommunityFreeVaultCreationPolicy(),
    autosaveDelay: delay,
    now: () => now,
  );
}

RecordTypeDefinition _template(String id) =>
    BuiltInTemplateCatalog.all.singleWhere((value) => value.stableId == id);

final class _EditorPort implements RecordEditorPort {
  _EditorPort({this.failSave = false});

  final bool failSave;
  int saveCalls = 0;
  int commitCalls = 0;

  @override
  Future<EditorDraftSaveResult> saveDraft(
    EditorDraftDocument draft, {
    required bool alreadyPersisted,
    required DateTime now,
  }) async {
    saveCalls++;
    if (failSave) throw const VaultFailure(VaultFailureCode.storageFull);
    return EditorDraftSaveResult.saved(draft);
  }

  @override
  Future<RecordMutationResult> commit(
    EditorDraftDocument draft, {
    required DateTime now,
    required bool draftWasPersisted,
  }) async {
    commitCalls++;
    return RecordMutationResult.saved(draft.snapshot.materialize(now: now));
  }

  @override
  Future<void> discardDraft(EditorDraftDocument draft) async {}
}

final class _DelayedPort implements RecordEditorPort {
  final release = Completer<void>();

  @override
  Future<EditorDraftSaveResult> saveDraft(
    EditorDraftDocument draft, {
    required bool alreadyPersisted,
    required DateTime now,
  }) async {
    await release.future;
    return EditorDraftSaveResult.saved(draft);
  }

  @override
  Future<RecordMutationResult> commit(
    EditorDraftDocument draft, {
    required DateTime now,
    required bool draftWasPersisted,
  }) async => RecordMutationResult.saved(draft.snapshot.materialize(now: now));

  @override
  Future<void> discardDraft(EditorDraftDocument draft) async {}
}

final class _AllowPolicy implements VaultCreationPolicy {
  const _AllowPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

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
  Future<List<EncryptedObject>> readAll() async => values.values.toList();

  @override
  Future<void> remove({
    required String objectId,
    required int expectedRevision,
  }) async {
    final current = values[objectId];
    if (current == null || current.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values.remove(objectId);
  }

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

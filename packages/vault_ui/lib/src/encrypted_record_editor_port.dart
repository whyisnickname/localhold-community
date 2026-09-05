// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'record_editor_controller.dart';

/// Local-only production adapter. Both services use the same unlocked vault
/// cipher/repository; this adapter contains no backend or network dependency.
final class EncryptedRecordEditorPort implements RecordEditorPort {
  const EncryptedRecordEditorPort({
    required this.records,
    required this.drafts,
  });

  final EncryptedRecordService records;
  final EncryptedEditorDraftService drafts;

  @override
  Future<EditorDraftSaveResult> saveDraft(
    EditorDraftDocument draft, {
    required bool alreadyPersisted,
    required DateTime now,
  }) => alreadyPersisted
      ? drafts.replace(draft: draft, expectedRevision: draft.revision, now: now)
      : drafts.create(draft);

  @override
  Future<RecordMutationResult> commit(
    EditorDraftDocument draft, {
    required DateTime now,
    required bool draftWasPersisted,
  }) async {
    final targetRevision = draft.baseRecordRevision;
    final proposed = draft.snapshot.materialize(
      now: now,
      revision: targetRevision ?? 1,
    );
    final result = targetRevision == null
        ? await records.create(proposed)
        : await records.update(
            proposed: proposed,
            expectedRevision: targetRevision,
            now: now,
          );
    if (!result.hasConflict && draftWasPersisted) {
      try {
        await drafts.discard(draft);
      } on Object {
        // A saved record is authoritative. Retaining an encrypted draft is a
        // safe recoverable duplicate and avoids a misleading save retry that
        // could create another record. Draft reconciliation runs on reopen.
      }
    }
    return result;
  }

  @override
  Future<void> discardDraft(EditorDraftDocument draft) => drafts.discard(draft);
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

abstract interface class RecordEditorPort {
  Future<EditorDraftSaveResult> saveDraft(
    EditorDraftDocument draft, {
    required bool alreadyPersisted,
    required DateTime now,
  });

  /// Commits the record and consumes the draft after a successful save.
  Future<RecordMutationResult> commit(
    EditorDraftDocument draft, {
    required DateTime now,
    required bool draftWasPersisted,
  });

  Future<void> discardDraft(EditorDraftDocument draft);
}

enum EditorPersistenceStatus {
  idle,
  saving,
  saved,
  recoverableFailure,
  conflict,
}

final class RecordEditorController extends ChangeNotifier {
  RecordEditorController({
    required EditorDraftDocument draft,
    required this.template,
    required RecordEditorPort port,
    required VaultCreationPolicy creationPolicy,
    bool draftWasPersisted = false,
    Duration autosaveDelay = const Duration(milliseconds: 750),
    DateTime Function()? now,
  }) : _draft = draft,
       _port = port,
       _creationPolicy = creationPolicy,
       _persisted = draftWasPersisted,
       _autosaveDelay = autosaveDelay,
       _now = now ?? DateTime.now {
    if (draft.snapshot.typeId != template.stableId ||
        autosaveDelay.isNegative) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final RecordTypeDefinition template;
  final RecordEditorPort _port;
  final VaultCreationPolicy _creationPolicy;
  final Duration _autosaveDelay;
  final DateTime Function() _now;
  EditorDraftDocument _draft;
  EditorRemovedField? _undoRemoval;
  Timer? _timer;
  Future<void> _writeTail = Future.value();
  int _generation = 0;
  int _savedGeneration = 0;
  bool _persisted;
  bool _committing = false;
  bool _disposed = false;
  EditorPersistenceStatus _status = EditorPersistenceStatus.idle;

  EditorDraftDocument get draft => _draft;
  EditorDraftSnapshot get snapshot => _draft.snapshot;
  EditorRemovedField? get undoRemoval => _undoRemoval;
  bool get isDirty => _generation != _savedGeneration;
  bool get isCommitting => _committing;
  bool get isEditingExisting => _draft.targetRecordId != null;
  EditorPersistenceStatus get persistenceStatus => _status;

  void updateField(FieldId fieldId, Object? value) {
    _mutate(_draft.snapshot.withFieldValue(fieldId, value));
  }

  EditorRemovalPlan planRemoval(FieldId fieldId) =>
      _draft.snapshot.planRemoval(fieldId);

  void applyRemoval(EditorRemovalPlan plan) {
    if (!identical(plan.source, _draft.snapshot)) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    _undoRemoval = plan.removed;
    _mutate(plan.apply());
  }

  void undoLastRemoval() {
    final removed = _undoRemoval;
    if (removed == null) return;
    _undoRemoval = null;
    _mutate(_draft.snapshot.restore(removed));
  }

  VaultField addPremiumField({
    required VaultFieldKind kind,
    required String label,
    Object? value,
    Map<String, Object?> options = const {},
  }) {
    if (label.trim().isEmpty) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    _creationPolicy.requireAllowed(VaultCreationCapability.customField);
    if (kind == VaultFieldKind.totp) {
      _creationPolicy.requireAllowed(VaultCreationCapability.totp);
    }
    if (kind == VaultFieldKind.attachment) {
      _creationPolicy.requireAllowed(VaultCreationCapability.attachment);
    }
    final field = VaultField(
      id: FieldId.generate(),
      kind: kind,
      label: label,
      value: value,
      options: options,
    );
    _mutate(_draft.snapshot.copyWith(fields: [...snapshot.fields, field]));
    return field;
  }

  Future<bool> saveDraftNow() {
    if (_disposed) return Future.value(false);
    _timer?.cancel();
    final completer = Completer<bool>();
    _writeTail = _writeTail.then((_) async {
      completer.complete(await _persistCurrent());
    });
    return completer.future;
  }

  Future<RecordMutationResult?> commit() async {
    if (_disposed || _committing) return null;
    try {
      _draft.snapshot.materialize(now: _now());
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.invalidInput) return null;
      rethrow;
    }
    _timer?.cancel();
    await _writeTail;
    _committing = true;
    _notify();
    try {
      final result = await _port.commit(
        _draft,
        now: _now().toUtc(),
        draftWasPersisted: _persisted,
      );
      if (result.hasConflict) {
        _status = EditorPersistenceStatus.conflict;
      } else {
        _savedGeneration = _generation;
        _persisted = false;
        _undoRemoval = null;
        _status = EditorPersistenceStatus.saved;
      }
      return result;
    } on Object {
      _status = EditorPersistenceStatus.recoverableFailure;
      return null;
    } finally {
      _committing = false;
      _notify();
    }
  }

  Future<bool> discard() async {
    if (_disposed) return false;
    _timer?.cancel();
    await _writeTail;
    try {
      if (_persisted) await _port.discardDraft(_draft);
      _savedGeneration = _generation;
      _persisted = false;
      _undoRemoval = null;
      _status = EditorPersistenceStatus.idle;
      _notify();
      return true;
    } on Object {
      _status = EditorPersistenceStatus.recoverableFailure;
      _notify();
      return false;
    }
  }

  void _mutate(EditorDraftSnapshot snapshot) {
    _generation++;
    _draft = _draft.copyWith(snapshot: snapshot, updatedAt: _now().toUtc());
    _status = EditorPersistenceStatus.idle;
    _timer?.cancel();
    _timer = Timer(_autosaveDelay, () {
      unawaited(saveDraftNow());
    });
    _notify();
  }

  Future<bool> _persistCurrent() async {
    final attemptGeneration = _generation;
    final attempted = _draft.copyWith(updatedAt: _now().toUtc());
    _status = EditorPersistenceStatus.saving;
    _notify();
    try {
      final result = await _port.saveDraft(
        attempted,
        alreadyPersisted: _persisted,
        now: _now().toUtc(),
      );
      final saved = result.draft ?? result.conflictCopy;
      if (saved == null) throw StateError('Missing saved editor draft');
      _persisted = true;
      _savedGeneration = attemptGeneration;
      _draft = attemptGeneration == _generation
          ? saved
          : saved.copyWith(
              snapshot: _draft.snapshot,
              updatedAt: _draft.updatedAt,
            );
      _status = result.conflictCopy != null
          ? EditorPersistenceStatus.conflict
          : (isDirty
                ? EditorPersistenceStatus.idle
                : EditorPersistenceStatus.saved);
      _notify();
      return true;
    } on Object {
      _status = EditorPersistenceStatus.recoverableFailure;
      _notify();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

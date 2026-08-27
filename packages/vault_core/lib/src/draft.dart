// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'document_codec.dart';
import 'document_repository.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';
import 'repository.dart';
import 'vault_health.dart';

final class VaultDraft {
  VaultDraft({
    required this.id,
    required this.recordSnapshot,
    required this.updatedAt,
    this.targetRecordId,
    this.baseRecordRevision,
    this.revision = 1,
  }) {
    if (revision < 1 ||
        (targetRecordId == null) != (baseRecordRevision == null) ||
        (baseRecordRevision != null && baseRecordRevision! < 1)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final DraftId id;
  final RecordId? targetRecordId;
  final int? baseRecordRevision;
  final VaultRecord recordSnapshot;
  final DateTime updatedAt;
  final int revision;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id.value,
    'targetRecordId': targetRecordId?.value,
    'baseRecordRevision': baseRecordRevision,
    'recordSnapshot': recordSnapshot.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
  };

  factory VaultDraft.fromJson(Map<String, Object?> json) {
    try {
      if (json['schemaVersion'] != 1) {
        throw const VaultFailure(VaultFailureCode.unsupportedVersion);
      }
      return VaultDraft(
        id: DraftId.parse(json['id']! as String),
        targetRecordId: switch (json['targetRecordId']) {
          final String value => RecordId.parse(value),
          _ => null,
        },
        baseRecordRevision: json['baseRecordRevision'] as int?,
        recordSnapshot: VaultRecord.fromJson(
          Map<String, Object?>.from(
            json['recordSnapshot']! as Map<Object?, Object?>,
          ),
        ),
        updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
        revision: json['revision']! as int,
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  VaultDraft copyWith({
    DraftId? id,
    VaultRecord? recordSnapshot,
    DateTime? updatedAt,
    int? revision,
  }) => VaultDraft(
    id: id ?? this.id,
    targetRecordId: targetRecordId,
    baseRecordRevision: baseRecordRevision,
    recordSnapshot: recordSnapshot ?? this.recordSnapshot,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
  );
}

final class DraftSaveResult {
  const DraftSaveResult.saved(this.draft) : conflictCopy = null;
  const DraftSaveResult.conflict(this.conflictCopy) : draft = null;

  final VaultDraft? draft;
  final VaultDraft? conflictCopy;
}

typedef DraftAutosaveOperation = Future<DraftSaveResult> Function();

/// Debounces editor changes and runs at most one draft write at a time.
///
/// The caller owns the draft revision and supplies an operation that captures
/// the latest editor snapshot. A newly scheduled operation replaces only work
/// that has not started; an in-flight write is allowed to finish first.
final class DraftAutosaveCoordinator {
  DraftAutosaveCoordinator({
    Duration idleDelay = const Duration(milliseconds: 750),
  }) : _idleDelay = idleDelay {
    if (idleDelay.isNegative) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final Duration _idleDelay;
  Timer? _timer;
  DraftAutosaveOperation? _pending;
  Future<void> _writeTail = Future.value();
  bool _disposed = false;

  bool get hasPendingWrite => _pending != null;

  void schedule(DraftAutosaveOperation operation) {
    _ensureAlive();
    _pending = operation;
    _timer?.cancel();
    _timer = Timer(_idleDelay, () {
      unawaited(_drain());
    });
  }

  Future<DraftSaveResult?> flush() {
    _ensureAlive();
    _timer?.cancel();
    return _drain();
  }

  void cancelPending() {
    _ensureAlive();
    _timer?.cancel();
    _pending = null;
  }

  Future<void> dispose({bool flushPending = true}) async {
    if (_disposed) return;
    _timer?.cancel();
    if (flushPending) {
      await _drain();
    } else {
      _pending = null;
    }
    await _writeTail;
    _disposed = true;
  }

  Future<DraftSaveResult?> _drain() {
    final operation = _pending;
    _pending = null;
    if (operation == null) return Future.value();
    final completer = Completer<DraftSaveResult?>();
    _writeTail = _writeTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('Draft autosave has been disposed');
  }
}

final class EncryptedDraftService {
  const EncryptedDraftService({
    required this._repository,
    required this._cipher,
    this._documents = const VaultDocumentCodec(),
    this._health,
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultDocumentCodec _documents;
  final VaultHealthController? _health;

  Future<DraftSaveResult> create(VaultDraft draft) async {
    _health?.requireWritable();
    if (draft.revision != 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    await _create(draft);
    return DraftSaveResult.saved(draft);
  }

  Future<DraftSaveResult> replace({
    required VaultDraft draft,
    required int expectedRevision,
    required DateTime now,
  }) async {
    _health?.requireWritable();
    final saved = draft.copyWith(
      revision: expectedRevision + 1,
      updatedAt: now.toUtc(),
    );
    final object = await _encryptedObject(saved);
    try {
      await _repository.replace(
        object: object,
        expectedRevision: expectedRevision,
      );
      return DraftSaveResult.saved(saved);
    } on VaultFailure catch (failure) {
      if (failure.code != VaultFailureCode.revisionConflict) rethrow;
      final copy = saved.copyWith(
        id: DraftId.generate(),
        revision: 1,
        updatedAt: now.toUtc(),
      );
      await _create(copy);
      return DraftSaveResult.conflict(copy);
    }
  }

  Future<List<VaultDraft>> loadAll() async {
    final result = <VaultDraft>[];
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      codec: _documents,
      health: _health,
    );
    final snapshot = await loader.loadAll();
    for (final encryptedDocument in snapshot.documents) {
      final object = encryptedDocument.object;
      final document = encryptedDocument.document;
      if (document.kind != 'draft') continue;
      try {
        final draft = VaultDraft.fromJson(document.payload);
        if (draft.id.value != object.objectId ||
            draft.revision != object.revision) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        result.add(draft);
      } on VaultFailure catch (failure) {
        if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
        await loader.quarantine(object, VaultFailureCode.integrityFailure);
      }
    }
    return List.unmodifiable(result);
  }

  List<VaultDraft> abandonedCandidates(
    Iterable<VaultDraft> drafts, {
    required DateTime now,
    Duration retention = const Duration(days: 30),
  }) => List.unmodifiable(
    drafts.where(
      (draft) => now.toUtc().difference(draft.updatedAt) >= retention,
    ),
  );

  Future<void> discard(VaultDraft draft) async {
    _health?.requireWritable();
    await _repository.remove(
      objectId: draft.id.value,
      expectedRevision: draft.revision,
    );
  }

  Future<void> _create(VaultDraft draft) async {
    await _repository.create(await _encryptedObject(draft));
  }

  Future<EncryptedObject> _encryptedObject(VaultDraft draft) async {
    final plaintext = _documents.encode(kind: 'draft', payload: draft.toJson());
    try {
      final aad = ObjectAuthenticationData.encode(
        vaultId: _cipher.vaultId,
        objectId: draft.id.value,
        revision: draft.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
      );
      final envelope = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: aad,
      );
      return EncryptedObject(
        objectId: draft.id.value,
        revision: draft.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
        envelope: envelope,
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'document_codec.dart';
import 'document_repository.dart';
import 'creation_policy.dart';
import 'duplicates.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';
import 'repository.dart';
import 'templates.dart';
import 'vault_health.dart';

final class VaultRecordCodec {
  const VaultRecordCodec({this._documents = const VaultDocumentCodec()});

  final VaultDocumentCodec _documents;

  Uint8List encode(VaultRecord record) {
    return _documents.encode(kind: 'record', payload: record.toJson());
  }

  VaultRecord decode(Uint8List bytes) {
    final document = _documents.decode(bytes);
    if (document.kind != 'record') throw const VaultObjectKindMismatch();
    return VaultRecord.fromJson(document.payload);
  }
}

final class VaultObjectKindMismatch implements Exception {
  const VaultObjectKindMismatch();
}

final class RecordLoadSnapshot {
  const RecordLoadSnapshot({
    required this.records,
    required this.quarantinedObjectIds,
  });

  final List<VaultRecord> records;
  final List<String> quarantinedObjectIds;
}

final class RecordMutationResult {
  const RecordMutationResult.saved(this.record) : conflictCopy = null;
  const RecordMutationResult.conflict(this.conflictCopy) : record = null;

  final VaultRecord? record;
  final VaultRecord? conflictCopy;
  bool get hasConflict => conflictCopy != null;
}

final class EncryptedRecordService {
  const EncryptedRecordService({
    required this._repository,
    required this._cipher,
    required this._creationPolicy,
    this._codec = const VaultRecordCodec(),
    this._health,
    this._mergePlanner,
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultCreationPolicy _creationPolicy;
  final VaultRecordCodec _codec;
  final VaultHealthController? _health;
  final RecordMergePlanner? _mergePlanner;

  Future<VaultRecord?> read(RecordId recordId) async {
    final object = await _repository.read(recordId.value);
    if (object == null) return null;
    try {
      return await _decrypt(object);
    } on VaultFailure catch (failure) {
      if (_isObjectCorruption(failure.code)) {
        if (!(_health?.isReadOnly ?? false)) {
          await _repository.quarantine(
            objectId: object.objectId,
            expectedRevision: object.revision,
            reason: failure.code,
          );
          _health?.recordObjectQuarantine();
        }
      }
      rethrow;
    }
  }

  Future<RecordLoadSnapshot> loadAll() async {
    final records = <VaultRecord>[];
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      health: _health,
    );
    final snapshot = await loader.loadAll();
    final quarantined = [...snapshot.quarantinedObjectIds];
    for (final encryptedDocument in snapshot.documents) {
      final object = encryptedDocument.object;
      final document = encryptedDocument.document;
      if (document.kind != 'record') continue;
      try {
        final record = VaultRecord.fromJson(document.payload);
        if (record.id.value != object.objectId ||
            record.revision != object.revision) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        records.add(record);
      } on VaultFailure catch (failure) {
        if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
        await loader.quarantine(object, VaultFailureCode.integrityFailure);
        quarantined.add(object.objectId);
      }
    }
    return RecordLoadSnapshot(
      records: List.unmodifiable(records),
      quarantinedObjectIds: List.unmodifiable(quarantined),
    );
  }

  Future<RecordMutationResult> create(VaultRecord record) async {
    _health?.requireWritable();
    if (record.revision != 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    _requireCreationCapabilities(record.fields, typeId: record.typeId);
    await _create(record);
    return RecordMutationResult.saved(record);
  }

  Future<RecordMutationResult> update({
    required VaultRecord proposed,
    required int expectedRevision,
    required DateTime now,
  }) async {
    _health?.requireWritable();
    if (proposed.id.value.isEmpty || expectedRevision < 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final currentObject = await _repository.read(proposed.id.value);
    if (currentObject == null) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    final current = await _decrypt(currentObject);
    final existingFieldIds = current.fields
        .map((field) => field.id.value)
        .toSet();
    _requireCreationCapabilities(
      proposed.fields.where(
        (field) => !existingFieldIds.contains(field.id.value),
      ),
      typeId: proposed.typeId == current.typeId ? null : proposed.typeId,
    );
    final saved = proposed.copyWith(
      createdAt: current.createdAt,
      revision: expectedRevision + 1,
      updatedAt: now.toUtc(),
      conflictOf: current.conflictOf,
      clearConflict: current.conflictOf == null,
    );
    final encrypted = await _encryptedObject(saved);
    try {
      await _repository.replace(
        object: encrypted,
        expectedRevision: expectedRevision,
      );
      return RecordMutationResult.saved(saved);
    } on VaultFailure catch (failure) {
      if (failure.code != VaultFailureCode.revisionConflict) rethrow;
      final conflict = proposed.copyWith(
        id: RecordId.generate(),
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
        revision: 1,
        conflictOf: proposed.id,
      );
      await _create(conflict);
      return RecordMutationResult.conflict(conflict);
    }
  }

  Future<void> permanentlyDelete(VaultRecord record) async {
    _health?.requireWritable();
    await _repository.remove(
      objectId: record.id.value,
      expectedRevision: record.revision,
    );
  }

  Future<List<VaultRecord>> updateMany({
    required Iterable<VaultRecord> proposed,
    required DateTime now,
  }) async {
    _health?.requireWritable();
    final source = proposed.toList(growable: false);
    if (source.isEmpty) return const [];
    if (source.map((record) => record.id.value).toSet().length !=
        source.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final current = <VaultRecord>[];
    for (final proposedRecord in source) {
      final object = await _repository.read(proposedRecord.id.value);
      if (object == null) {
        throw const VaultFailure(VaultFailureCode.objectNotFound);
      }
      final persisted = await _decrypt(object);
      if (persisted.revision != proposedRecord.revision ||
          persisted.typeId != proposedRecord.typeId ||
          persisted.createdAt != proposedRecord.createdAt ||
          persisted.conflictOf != proposedRecord.conflictOf ||
          jsonEncode(
                persisted.fields.map((field) => field.toJson()).toList(),
              ) !=
              jsonEncode(
                proposedRecord.fields.map((field) => field.toJson()).toList(),
              )) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      current.add(persisted);
    }
    final saved = List<VaultRecord>.generate(source.length, (index) {
      final persisted = current[index];
      final proposedRecord = source[index];
      return persisted.copyWith(
        revision: persisted.revision + 1,
        updatedAt: now.toUtc(),
        lifecycle: proposedRecord.lifecycle,
        favorite: proposedRecord.favorite,
        pinned: proposedRecord.pinned,
        folderId: proposedRecord.folderId,
        clearFolder: proposedRecord.folderId == null,
        tagIds: proposedRecord.tagIds,
      );
    }, growable: false);
    final replacements = <ExpectedEncryptedObject>[];
    for (var index = 0; index < source.length; index++) {
      replacements.add(
        ExpectedEncryptedObject(
          object: await _encryptedObject(saved[index]),
          expectedRevision: source[index].revision,
        ),
      );
    }
    final repository = _repository;
    if (repository is AtomicCiphertextRepository) {
      await repository.replaceMany(replacements);
    } else if (replacements.length == 1) {
      final replacement = replacements.single;
      await repository.replace(
        object: replacement.object,
        expectedRevision: replacement.expectedRevision,
      );
    } else {
      throw const VaultFailure(VaultFailureCode.capabilityUnavailable);
    }
    return List.unmodifiable(saved);
  }

  /// Atomically replaces the selected target and moves the source to Trash.
  ///
  /// Both records are re-read and authenticated here. This dedicated path is
  /// intentionally separate from the metadata-only [updateMany] contract.
  Future<RecordMergeResult> merge({
    required RecordMergeCommand command,
    required DateTime now,
  }) async {
    _health?.requireWritable();
    final repository = _repository;
    if (repository is! AtomicCiphertextRepository) {
      throw const VaultFailure(VaultFailureCode.capabilityUnavailable);
    }
    final targetObject = await repository.read(command.targetId.value);
    final sourceObject = await repository.read(command.sourceId.value);
    if (targetObject == null || sourceObject == null) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    if (targetObject.revision != command.expectedTargetRevision ||
        sourceObject.revision != command.expectedSourceRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    final target = await _decrypt(targetObject);
    final source = await _decrypt(sourceObject);
    final planner =
        _mergePlanner ??
        RecordMergePlanner(definitions: BuiltInTemplateCatalog.all);
    final preview = planner.prepare(target: target, source: source);
    final proposed = planner.apply(
      preview: preview,
      choices: command.choices,
      now: now,
    );
    final savedTarget = proposed.target.copyWith(
      revision: target.revision + 1,
      updatedAt: now.toUtc(),
    );
    final savedSource = proposed.source.copyWith(
      revision: source.revision + 1,
      updatedAt: now.toUtc(),
    );
    final targetEncrypted = await _encryptedObject(savedTarget);
    final sourceEncrypted = await _encryptedObject(savedSource);
    await repository.replaceMany([
      ExpectedEncryptedObject(
        object: targetEncrypted,
        expectedRevision: target.revision,
      ),
      ExpectedEncryptedObject(
        object: sourceEncrypted,
        expectedRevision: source.revision,
      ),
    ]);
    return RecordMergeResult(target: savedTarget, source: savedSource);
  }

  Future<void> _create(VaultRecord record) async {
    await _repository.create(await _encryptedObject(record));
  }

  Future<EncryptedObject> _encryptedObject(VaultRecord record) async {
    final plaintext = _codec.encode(record);
    try {
      final aad = ObjectAuthenticationData.encode(
        vaultId: _cipher.vaultId,
        objectId: record.id.value,
        revision: record.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
      );
      final envelope = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: aad,
      );
      return EncryptedObject(
        objectId: record.id.value,
        revision: record.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
        envelope: envelope,
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Future<VaultRecord> _decrypt(EncryptedObject object) async {
    if (object.schemaVersion != 1 ||
        object.keyGenerationId != _cipher.keyGenerationId) {
      throw const VaultFailure(VaultFailureCode.unsupportedVersion);
    }
    final aad = ObjectAuthenticationData.encode(
      vaultId: _cipher.vaultId,
      objectId: object.objectId,
      revision: object.revision,
      schemaVersion: object.schemaVersion,
      keyGenerationId: object.keyGenerationId,
    );
    final plaintext = await _cipher.decrypt(
      envelope: object.envelope,
      authenticatedData: aad,
    );
    try {
      final record = _codec.decode(plaintext);
      if (record.id.value != object.objectId ||
          record.revision != object.revision) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      return record;
    } on VaultObjectKindMismatch {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  bool _isObjectCorruption(VaultFailureCode code) =>
      code == VaultFailureCode.integrityFailure ||
      code == VaultFailureCode.payloadTooLarge;

  void _requireCreationCapabilities(
    Iterable<VaultField> fields, {
    String? typeId,
  }) {
    if (typeId != null && typeId.startsWith('localhold.custom.')) {
      _creationPolicy.requireAllowed(VaultCreationCapability.customType);
    }
    for (final field in fields) {
      if (field.definitionId == null) {
        _creationPolicy.requireAllowed(VaultCreationCapability.customField);
      }
      if (field.kind == VaultFieldKind.totp) {
        _creationPolicy.requireAllowed(VaultCreationCapability.totp);
      }
      if (field.kind == VaultFieldKind.attachment) {
        _creationPolicy.requireAllowed(VaultCreationCapability.attachment);
      }
    }
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'document_codec.dart';
import 'document_repository.dart';
import 'creation_policy.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';
import 'repository.dart';
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
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultCreationPolicy _creationPolicy;
  final VaultRecordCodec _codec;
  final VaultHealthController? _health;

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

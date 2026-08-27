// SPDX-License-Identifier: MPL-2.0

import 'document_codec.dart';
import 'document_repository.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'repository.dart';
import 'vault_health.dart';

final class VaultMetadata {
  VaultMetadata({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
  }) {
    if (name.trim().isEmpty ||
        name.length > 256 ||
        revision < 1 ||
        updatedAt.toUtc().isBefore(createdAt.toUtc())) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final VaultId id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id.value,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
  };

  factory VaultMetadata.fromJson(Map<String, Object?> json) {
    try {
      if (json['schemaVersion'] != 1) {
        throw const VaultFailure(VaultFailureCode.unsupportedVersion);
      }
      return VaultMetadata(
        id: VaultId.parse(json['id']! as String),
        name: json['name']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
        revision: json['revision']! as int,
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  VaultMetadata rename(String value, DateTime now) => VaultMetadata(
    id: id,
    name: value,
    createdAt: createdAt,
    updatedAt: now.toUtc(),
    revision: revision,
  );
}

abstract interface class VaultSelectionStore {
  Future<VaultId?> readLastSelected();

  Future<void> select(VaultId id);

  Future<void> clearIfSelected(VaultId id);
}

final class EncryptedVaultMetadataService {
  const EncryptedVaultMetadataService({
    required this._repository,
    required this._cipher,
    this._documents = const VaultDocumentCodec(),
    this._health,
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultDocumentCodec _documents;
  final VaultHealthController? _health;

  Future<void> create(VaultMetadata metadata) async {
    _health?.requireWritable();
    if (metadata.revision != 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    await _repository.create(await _encrypt(metadata));
  }

  Future<VaultMetadata?> read(VaultId id) async {
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      codec: _documents,
      health: _health,
    );
    final encrypted = await loader.read(id.value);
    if (encrypted == null) return null;
    try {
      if (encrypted.document.kind != 'vault_metadata') {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      final metadata = VaultMetadata.fromJson(encrypted.document.payload);
      if (metadata.id != id || metadata.revision != encrypted.object.revision) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      return metadata;
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
      await loader.quarantine(
        encrypted.object,
        VaultFailureCode.integrityFailure,
      );
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  Future<VaultMetadata> rename({
    required VaultMetadata current,
    required String name,
    required DateTime now,
  }) async {
    _health?.requireWritable();
    final updated = current
        .rename(name, now)
        .copyWithRevision(current.revision + 1);
    await _repository.replace(
      object: await _encrypt(updated),
      expectedRevision: current.revision,
    );
    return updated;
  }

  Future<EncryptedObject> _encrypt(VaultMetadata metadata) async {
    final plaintext = _documents.encode(
      kind: 'vault_metadata',
      payload: metadata.toJson(),
    );
    try {
      final aad = ObjectAuthenticationData.encode(
        vaultId: _cipher.vaultId,
        objectId: metadata.id.value,
        revision: metadata.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
      );
      final envelope = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: aad,
      );
      return EncryptedObject(
        objectId: metadata.id.value,
        revision: metadata.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
        envelope: envelope,
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}

extension on VaultMetadata {
  VaultMetadata copyWithRevision(int revision) => VaultMetadata(
    id: id,
    name: name,
    createdAt: createdAt,
    updatedAt: updatedAt,
    revision: revision,
  );
}

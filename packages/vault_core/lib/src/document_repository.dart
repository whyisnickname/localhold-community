// SPDX-License-Identifier: MPL-2.0

import 'document_codec.dart';
import 'errors.dart';
import 'repository.dart';
import 'vault_health.dart';

final class EncryptedVaultDocument {
  const EncryptedVaultDocument({required this.object, required this.document});

  final EncryptedObject object;
  final VaultDocument document;
}

final class VaultDocumentLoadSnapshot {
  const VaultDocumentLoadSnapshot({
    required this.documents,
    required this.quarantinedObjectIds,
  });

  final List<EncryptedVaultDocument> documents;
  final List<String> quarantinedObjectIds;
}

/// Single ciphertext-to-document boundary shared by all domain repositories.
/// Object-local corruption is quarantined while version/domain mismatches fail
/// closed without mutating the unsupported object.
final class EncryptedVaultDocumentLoader {
  const EncryptedVaultDocumentLoader({
    required this._repository,
    required this._cipher,
    this._codec = const VaultDocumentCodec(),
    this._health,
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultDocumentCodec _codec;
  final VaultHealthController? _health;

  Future<EncryptedVaultDocument?> read(String objectId) async {
    final object = await _repository.read(objectId);
    if (object == null) return null;
    try {
      return await _decrypt(object);
    } on VaultFailure catch (failure) {
      if (_isObjectCorruption(failure.code)) {
        await _quarantine(object, failure.code);
      }
      rethrow;
    }
  }

  Future<VaultDocumentLoadSnapshot> loadAll() async {
    final documents = <EncryptedVaultDocument>[];
    final quarantined = <String>[];
    for (final object in await _repository.readAll()) {
      try {
        documents.add(await _decrypt(object));
      } on VaultFailure catch (failure) {
        if (!_isObjectCorruption(failure.code)) rethrow;
        await _quarantine(object, failure.code);
        quarantined.add(object.objectId);
      }
    }
    return VaultDocumentLoadSnapshot(
      documents: List.unmodifiable(documents),
      quarantinedObjectIds: List.unmodifiable(quarantined),
    );
  }

  Future<void> quarantine(EncryptedObject object, VaultFailureCode reason) =>
      _quarantine(object, reason);

  Future<EncryptedVaultDocument> _decrypt(EncryptedObject object) async {
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
      return EncryptedVaultDocument(
        object: object,
        document: _codec.decode(plaintext),
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Future<void> _quarantine(
    EncryptedObject object,
    VaultFailureCode reason,
  ) async {
    if (_health?.isReadOnly ?? false) return;
    await _repository.quarantine(
      objectId: object.objectId,
      expectedRevision: object.revision,
      reason: reason,
    );
    _health?.recordObjectQuarantine();
  }

  bool _isObjectCorruption(VaultFailureCode code) =>
      code == VaultFailureCode.integrityFailure ||
      code == VaultFailureCode.payloadTooLarge;
}

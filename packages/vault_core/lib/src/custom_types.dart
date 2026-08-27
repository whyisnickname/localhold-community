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

final class CustomTypeDocument {
  CustomTypeDocument({
    required this.objectId,
    required this.definition,
    this.revision = 1,
  }) {
    if (definition.builtIn ||
        !RegExp(r'^localhold\.custom\.[A-Za-z0-9_-]{22}$')
            .hasMatch(definition.stableId) ||
        revision < 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final RecordId objectId;
  final RecordTypeDefinition definition;
  final int revision;

  CustomTypeDocument copyWith({
    RecordTypeDefinition? definition,
    int? revision,
  }) => CustomTypeDocument(
    objectId: objectId,
    definition: definition ?? this.definition,
    revision: revision ?? this.revision,
  );

  factory CustomTypeDocument.create({
    required String name,
    required Iterable<FieldDefinition> fields,
  }) {
    final id = OpaqueId.generate();
    return CustomTypeDocument(
      objectId: RecordId.generate(),
      definition: RecordTypeDefinition(
        stableId: 'localhold.custom.$id',
        defaultName: name,
        fields: fields,
        builtIn: false,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'objectId': objectId.value,
    'revision': revision,
    'stableId': definition.stableId,
    'name': definition.defaultName,
    'fields': definition.fields
        .map(
          (field) => {
            'stableId': field.stableId,
            'kind': field.kind.name,
            'label': field.defaultLabel,
            'protected': field.protected,
          },
        )
        .toList(growable: false),
  };

  factory CustomTypeDocument.fromJson(Map<String, Object?> json) {
    try {
      if (json['schemaVersion'] != 1) {
        throw const VaultFailure(VaultFailureCode.unsupportedVersion);
      }
      return CustomTypeDocument(
        objectId: RecordId.parse(json['objectId']! as String),
        revision: json['revision']! as int,
        definition: RecordTypeDefinition(
          stableId: json['stableId']! as String,
          defaultName: json['name']! as String,
          builtIn: false,
          fields: (json['fields']! as List<Object?>).map((value) {
            final field = value! as Map<Object?, Object?>;
            return FieldDefinition(
              stableId: field['stableId']! as String,
              kind: VaultFieldKind.values.byName(field['kind']! as String),
              defaultLabel: field['label']! as String,
              protected: field['protected']! as bool,
            );
          }),
        ),
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }
}

final class EncryptedCustomTypeService {
  const EncryptedCustomTypeService({
    required this._repository,
    required this._cipher,
    required this._creationPolicy,
    this._documents = const VaultDocumentCodec(),
    this._health,
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultCreationPolicy _creationPolicy;
  final VaultDocumentCodec _documents;
  final VaultHealthController? _health;

  Future<void> create(CustomTypeDocument customType) async {
    _health?.requireWritable();
    _creationPolicy.requireAllowed(VaultCreationCapability.customType);
    await _repository.create(await _encrypt(customType));
  }

  Future<CustomTypeDocument?> read(RecordId objectId) async {
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      codec: _documents,
      health: _health,
    );
    final encrypted = await loader.read(objectId.value);
    if (encrypted == null) return null;
    try {
      if (encrypted.document.kind != 'custom_type') {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      final value = CustomTypeDocument.fromJson(encrypted.document.payload);
      if (value.objectId.value != encrypted.object.objectId ||
          value.revision != encrypted.object.revision) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      return value;
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
      await loader.quarantine(
        encrypted.object,
        VaultFailureCode.integrityFailure,
      );
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  Future<CustomTypeDocument> update({
    required CustomTypeDocument proposed,
    required int expectedRevision,
  }) async {
    _health?.requireWritable();
    if (expectedRevision < 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final current = await read(proposed.objectId);
    if (current == null) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    if (proposed.definition.stableId != current.definition.stableId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final existingFields = current.definition.fields
        .map((field) => field.stableId)
        .toSet();
    if (proposed.definition.fields.any(
      (field) => !existingFields.contains(field.stableId),
    )) {
      _creationPolicy.requireAllowed(VaultCreationCapability.customField);
    }
    final updated = proposed.copyWith(revision: expectedRevision + 1);
    await _repository.replace(
      object: await _encrypt(updated),
      expectedRevision: expectedRevision,
    );
    return updated;
  }

  Future<void> remove(CustomTypeDocument customType) async {
    _health?.requireWritable();
    await _repository.remove(
      objectId: customType.objectId.value,
      expectedRevision: customType.revision,
    );
  }

  Future<List<CustomTypeDocument>> loadAll() async {
    final result = <CustomTypeDocument>[];
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
      if (document.kind != 'custom_type') continue;
      try {
        final value = CustomTypeDocument.fromJson(document.payload);
        if (value.objectId.value != object.objectId ||
            value.revision != object.revision) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        result.add(value);
      } on VaultFailure catch (failure) {
        if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
        await loader.quarantine(object, VaultFailureCode.integrityFailure);
      }
    }
    return List.unmodifiable(result);
  }

  Future<EncryptedObject> _encrypt(CustomTypeDocument value) async {
    final plaintext = _documents.encode(
      kind: 'custom_type',
      payload: value.toJson(),
    );
    try {
      final aad = ObjectAuthenticationData.encode(
        vaultId: _cipher.vaultId,
        objectId: value.objectId.value,
        revision: value.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
      );
      final encrypted = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: aad,
      );
      return EncryptedObject(
        objectId: value.objectId.value,
        revision: value.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
        envelope: Uint8List.fromList(encrypted),
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}

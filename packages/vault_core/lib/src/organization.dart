// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'document_codec.dart';
import 'document_repository.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';
import 'repository.dart';
import 'vault_health.dart';

String canonicalIdentity(String value) => unicode
    .nfc(value)
    .toLowerCase()
    .replaceAll('ß', 'ss')
    .replaceAll('ς', 'σ')
    .trim();

final class VaultOrganization {
  VaultOrganization({
    required this.id,
    required Iterable<VaultFolder> folders,
    required Iterable<VaultTag> tags,
    this.revision = 1,
  }) : folders = List.unmodifiable(folders),
       tags = List.unmodifiable(tags) {
    _validate();
  }

  final OrganizationId id;
  final List<VaultFolder> folders;
  final List<VaultTag> tags;
  final int revision;

  factory VaultOrganization.empty() => VaultOrganization(
    id: OrganizationId.generate(),
    folders: const [],
    tags: const [],
  );

  VaultOrganization addFolder(VaultFolder folder) =>
      copyWith(folders: [...folders, folder]);

  VaultOrganization addTag(VaultTag tag) => copyWith(tags: [...tags, tag]);

  VaultOrganization copyWith({
    Iterable<VaultFolder>? folders,
    Iterable<VaultTag>? tags,
    int? revision,
  }) => VaultOrganization(
    id: id,
    folders: folders ?? this.folders,
    tags: tags ?? this.tags,
    revision: revision ?? this.revision,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id.value,
    'revision': revision,
    'folders': folders
        .map(
          (folder) => {
            'id': folder.id.value,
            'name': folder.name,
            'parentId': folder.parentId?.value,
          },
        )
        .toList(growable: false),
    'tags': tags
        .map((tag) => {'id': tag.id.value, 'name': tag.name})
        .toList(growable: false),
  };

  factory VaultOrganization.fromJson(Map<String, Object?> json) {
    try {
      if (json['schemaVersion'] != 1) {
        throw const VaultFailure(VaultFailureCode.unsupportedVersion);
      }
      return VaultOrganization(
        id: OrganizationId.parse(json['id']! as String),
        revision: json['revision']! as int,
        folders: (json['folders']! as List<Object?>).map((value) {
          final folder = value! as Map<Object?, Object?>;
          return VaultFolder(
            id: FolderId.parse(folder['id']! as String),
            name: folder['name']! as String,
            parentId: switch (folder['parentId']) {
              final String value => FolderId.parse(value),
              _ => null,
            },
          );
        }),
        tags: (json['tags']! as List<Object?>).map((value) {
          final tag = value! as Map<Object?, Object?>;
          return VaultTag(
            id: TagId.parse(tag['id']! as String),
            name: tag['name']! as String,
          );
        }),
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  void _validate() {
    if (revision < 1 ||
        folders.map((folder) => folder.id.value).toSet().length !=
            folders.length ||
        tags.map((tag) => tag.id.value).toSet().length != tags.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final folderIds = folders.map((folder) => folder.id.value).toSet();
    final folderById = {for (final folder in folders) folder.id.value: folder};
    final siblingNames = <String>{};
    for (final folder in folders) {
      if (folder.parentId != null &&
          !folderIds.contains(folder.parentId!.value)) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      final key =
          '${folder.parentId?.value ?? 'root'}\u0000${canonicalIdentity(folder.name)}';
      if (!siblingNames.add(key)) {
        throw const VaultFailure(VaultFailureCode.revisionConflict);
      }
      final visited = <String>{folder.id.value};
      var parent = folder.parentId;
      while (parent != null) {
        if (!visited.add(parent.value)) {
          throw const VaultFailure(VaultFailureCode.invalidInput);
        }
        parent = folderById[parent.value]?.parentId;
      }
    }
    final tagNames = <String>{};
    for (final tag in tags) {
      if (!tagNames.add(canonicalIdentity(tag.name))) {
        throw const VaultFailure(VaultFailureCode.revisionConflict);
      }
    }
  }
}

final class EncryptedOrganizationService {
  const EncryptedOrganizationService({
    required this._repository,
    required this._cipher,
    this._documents = const VaultDocumentCodec(),
    this._health,
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultDocumentCodec _documents;
  final VaultHealthController? _health;

  Future<void> create(VaultOrganization organization) async {
    _health?.requireWritable();
    await _repository.create(await _encrypt(organization));
  }

  Future<VaultOrganization> replace(
    VaultOrganization organization, {
    required int expectedRevision,
  }) async {
    _health?.requireWritable();
    final updated = organization.copyWith(revision: expectedRevision + 1);
    await _repository.replace(
      object: await _encrypt(updated),
      expectedRevision: expectedRevision,
    );
    return updated;
  }

  Future<VaultOrganization?> read(OrganizationId id) async {
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      codec: _documents,
      health: _health,
    );
    final encryptedDocument = await loader.read(id.value);
    if (encryptedDocument == null) return null;
    final object = encryptedDocument.object;
    try {
      final document = encryptedDocument.document;
      if (document.kind != 'organization') {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      final organization = VaultOrganization.fromJson(document.payload);
      if (organization.id.value != object.objectId ||
          organization.revision != object.revision) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      return organization;
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
      await loader.quarantine(object, VaultFailureCode.integrityFailure);
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  Future<EncryptedObject> _encrypt(VaultOrganization organization) async {
    final plaintext = _documents.encode(
      kind: 'organization',
      payload: organization.toJson(),
    );
    try {
      final aad = ObjectAuthenticationData.encode(
        vaultId: _cipher.vaultId,
        objectId: organization.id.value,
        revision: organization.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
      );
      final encrypted = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: aad,
      );
      return EncryptedObject(
        objectId: organization.id.value,
        revision: organization.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
        envelope: Uint8List.fromList(encrypted),
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}

VaultRecord setFavorite(VaultRecord record, bool favorite, DateTime now) =>
    record.copyWith(favorite: favorite, updatedAt: now.toUtc());

VaultRecord archiveRecord(VaultRecord record, DateTime now) => record.copyWith(
  lifecycle: RecordLifecycle.archived,
  updatedAt: now.toUtc(),
);

VaultRecord moveRecordToTrash(VaultRecord record, DateTime now) =>
    record.copyWith(lifecycle: RecordLifecycle.trashed, updatedAt: now.toUtc());

VaultRecord restoreRecord(VaultRecord record, DateTime now) =>
    record.copyWith(lifecycle: RecordLifecycle.active, updatedAt: now.toUtc());

List<VaultRecord> expiredTrashRecords(
  Iterable<VaultRecord> records, {
  required DateTime now,
  Duration retention = const Duration(days: 30),
}) => List.unmodifiable(
  records.where(
    (record) =>
        record.lifecycle == RecordLifecycle.trashed &&
        now.toUtc().difference(record.updatedAt) >= retention,
  ),
);

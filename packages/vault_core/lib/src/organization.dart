// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
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
      if (visited.length > VaultOrganizationMutations.maximumDepth) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
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

  Future<VaultOrganization?> loadCurrent() async {
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      codec: _documents,
      health: _health,
    );
    final snapshot = await loader.loadAll();
    final candidates = snapshot.documents
        .where((item) => item.document.kind == 'organization')
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    if (candidates.length != 1) {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
    final candidate = candidates.single;
    try {
      final organization = VaultOrganization.fromJson(
        candidate.document.payload,
      );
      if (organization.id.value != candidate.object.objectId ||
          organization.revision != candidate.object.revision) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      return organization;
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
      await loader.quarantine(
        candidate.object,
        VaultFailureCode.integrityFailure,
      );
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  Future<EncryptedOrganizationMutationResult> replaceWithRecords({
    required VaultOrganization organization,
    required Iterable<VaultRecord> records,
    required DateTime now,
  }) async {
    _health?.requireWritable();
    final repository = _repository;
    if (repository is! AtomicCiphertextRepository) {
      throw const VaultFailure(VaultFailureCode.capabilityUnavailable);
    }
    final sourceRecords = records.toList(growable: false);
    if (sourceRecords.map((record) => record.id.value).toSet().length !=
        sourceRecords.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final savedOrganization = organization.copyWith(
      revision: organization.revision + 1,
    );
    final currentRecords = <VaultRecord>[];
    for (final proposed in sourceRecords) {
      final object = await repository.read(proposed.id.value);
      if (object == null) {
        throw const VaultFailure(VaultFailureCode.objectNotFound);
      }
      final current = await _decryptRecord(object);
      if (current.revision != proposed.revision ||
          current.typeId != proposed.typeId ||
          current.createdAt != proposed.createdAt ||
          current.conflictOf != proposed.conflictOf ||
          jsonEncode(current.fields.map((field) => field.toJson()).toList()) !=
              jsonEncode(
                proposed.fields.map((field) => field.toJson()).toList(),
              )) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      currentRecords.add(current);
    }
    final savedRecords = List<VaultRecord>.generate(sourceRecords.length, (
      index,
    ) {
      final current = currentRecords[index];
      final proposed = sourceRecords[index];
      return current.copyWith(
        revision: current.revision + 1,
        updatedAt: now.toUtc(),
        lifecycle: proposed.lifecycle,
        favorite: proposed.favorite,
        pinned: proposed.pinned,
        folderId: proposed.folderId,
        clearFolder: proposed.folderId == null,
        tagIds: proposed.tagIds,
      );
    }, growable: false);
    final replacements = <ExpectedEncryptedObject>[
      ExpectedEncryptedObject(
        object: await _encrypt(savedOrganization),
        expectedRevision: organization.revision,
      ),
    ];
    for (var index = 0; index < sourceRecords.length; index++) {
      replacements.add(
        ExpectedEncryptedObject(
          object: await _encryptRecord(savedRecords[index]),
          expectedRevision: sourceRecords[index].revision,
        ),
      );
    }
    await repository.replaceMany(replacements);
    return EncryptedOrganizationMutationResult(
      organization: savedOrganization,
      records: savedRecords,
    );
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

  Future<EncryptedObject> _encryptRecord(VaultRecord record) async {
    final plaintext = _documents.encode(
      kind: 'record',
      payload: record.toJson(),
    );
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

  Future<VaultRecord> _decryptRecord(EncryptedObject object) async {
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
      final document = _documents.decode(plaintext);
      if (document.kind != 'record') {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      final record = VaultRecord.fromJson(document.payload);
      if (record.id.value != object.objectId ||
          record.revision != object.revision) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      return record;
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}

final class EncryptedOrganizationMutationResult {
  EncryptedOrganizationMutationResult({
    required this.organization,
    required Iterable<VaultRecord> records,
  }) : records = List.unmodifiable(records);

  final VaultOrganization organization;
  final List<VaultRecord> records;
}

VaultRecord setFavorite(VaultRecord record, bool favorite, DateTime now) =>
    record.copyWith(favorite: favorite, updatedAt: now.toUtc());

VaultRecord setPinned(VaultRecord record, bool pinned, DateTime now) =>
    record.copyWith(pinned: pinned, updatedAt: now.toUtc());

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

final class VaultOrganizationMutationResult {
  VaultOrganizationMutationResult({
    required this.organization,
    required Iterable<VaultRecord> records,
  }) : records = List.unmodifiable(records);

  final VaultOrganization organization;
  final List<VaultRecord> records;
}

abstract final class VaultOrganizationMutations {
  static const maximumDepth = 16;

  static VaultOrganization addFolder(
    VaultOrganization organization,
    VaultFolder folder,
  ) => organization.copyWith(folders: [...organization.folders, folder]);

  static VaultOrganization renameFolder(
    VaultOrganization organization,
    FolderId folderId,
    String name,
  ) {
    _requireFolder(organization, folderId);
    return organization.copyWith(
      folders: organization.folders
          .map(
            (folder) => folder.id == folderId
                ? VaultFolder(
                    id: folder.id,
                    name: name,
                    parentId: folder.parentId,
                  )
                : folder,
          )
          .toList(growable: false),
    );
  }

  static VaultOrganization moveFolder(
    VaultOrganization organization,
    FolderId folderId,
    FolderId? parentId,
  ) {
    _requireFolder(organization, folderId);
    if (parentId != null) _requireFolder(organization, parentId);
    return organization.copyWith(
      folders: organization.folders
          .map(
            (folder) => folder.id == folderId
                ? VaultFolder(
                    id: folder.id,
                    name: folder.name,
                    parentId: parentId,
                  )
                : folder,
          )
          .toList(growable: false),
    );
  }

  static VaultOrganizationMutationResult deleteFolder({
    required VaultOrganization organization,
    required Iterable<VaultRecord> records,
    required FolderId folderId,
    required DateTime now,
  }) {
    final deleted = _requireFolder(organization, folderId);
    final folders = organization.folders
        .where((folder) => folder.id != folderId)
        .map(
          (folder) => folder.parentId == folderId
              ? VaultFolder(
                  id: folder.id,
                  name: folder.name,
                  parentId: deleted.parentId,
                )
              : folder,
        )
        .toList(growable: false);
    final updatedRecords = records
        .where((record) => record.folderId == folderId)
        .map(
          (record) => record.copyWith(
            folderId: deleted.parentId,
            clearFolder: deleted.parentId == null,
            updatedAt: now.toUtc(),
          ),
        )
        .toList(growable: false);
    return VaultOrganizationMutationResult(
      organization: organization.copyWith(folders: folders),
      records: updatedRecords,
    );
  }

  static List<VaultFolder> breadcrumb(
    VaultOrganization organization,
    FolderId folderId,
  ) {
    final byId = {for (final folder in organization.folders) folder.id: folder};
    final result = <VaultFolder>[];
    VaultFolder? current = byId[folderId];
    if (current == null) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    while (current != null) {
      result.add(current);
      current = current.parentId == null ? null : byId[current.parentId];
    }
    return List.unmodifiable(result.reversed);
  }

  static VaultOrganization addTag(
    VaultOrganization organization,
    VaultTag tag,
  ) => organization.copyWith(tags: [...organization.tags, tag]);

  static VaultOrganization renameTag(
    VaultOrganization organization,
    TagId tagId,
    String name,
  ) {
    _requireTag(organization, tagId);
    return organization.copyWith(
      tags: organization.tags
          .map(
            (tag) => tag.id == tagId ? VaultTag(id: tag.id, name: name) : tag,
          )
          .toList(growable: false),
    );
  }

  static VaultOrganizationMutationResult mergeTag({
    required VaultOrganization organization,
    required Iterable<VaultRecord> records,
    required TagId sourceId,
    required TagId targetId,
    required DateTime now,
  }) {
    if (sourceId == targetId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    _requireTag(organization, sourceId);
    _requireTag(organization, targetId);
    return VaultOrganizationMutationResult(
      organization: organization.copyWith(
        tags: organization.tags
            .where((tag) => tag.id != sourceId)
            .toList(growable: false),
      ),
      records: records
          .where((record) => record.tagIds.contains(sourceId))
          .map(
            (record) => record.copyWith(
              tagIds: {
                ...record.tagIds.where((tag) => tag != sourceId),
                targetId,
              },
              updatedAt: now.toUtc(),
            ),
          )
          .toList(growable: false),
    );
  }

  static VaultOrganizationMutationResult deleteTag({
    required VaultOrganization organization,
    required Iterable<VaultRecord> records,
    required TagId tagId,
    required DateTime now,
  }) {
    _requireTag(organization, tagId);
    return VaultOrganizationMutationResult(
      organization: organization.copyWith(
        tags: organization.tags
            .where((tag) => tag.id != tagId)
            .toList(growable: false),
      ),
      records: records
          .where((record) => record.tagIds.contains(tagId))
          .map(
            (record) => record.copyWith(
              tagIds: record.tagIds.where((tag) => tag != tagId),
              updatedAt: now.toUtc(),
            ),
          )
          .toList(growable: false),
    );
  }

  static VaultFolder _requireFolder(
    VaultOrganization organization,
    FolderId folderId,
  ) => organization.folders.firstWhere(
    (folder) => folder.id == folderId,
    orElse: () => throw const VaultFailure(VaultFailureCode.objectNotFound),
  );

  static VaultTag _requireTag(VaultOrganization organization, TagId tagId) =>
      organization.tags.firstWhere(
        (tag) => tag.id == tagId,
        orElse: () => throw const VaultFailure(VaultFailureCode.objectNotFound),
      );
}

enum BulkRecordMutationKind {
  moveToFolder,
  addTags,
  removeTags,
  setFavorite,
  archive,
  moveToTrash,
}

final class BulkRecordCommand {
  const BulkRecordCommand.moveToFolder(this.folderId)
    : kind = BulkRecordMutationKind.moveToFolder,
      tagIds = const {},
      favorite = null;

  const BulkRecordCommand.addTags(this.tagIds)
    : kind = BulkRecordMutationKind.addTags,
      folderId = null,
      favorite = null;

  const BulkRecordCommand.removeTags(this.tagIds)
    : kind = BulkRecordMutationKind.removeTags,
      folderId = null,
      favorite = null;

  const BulkRecordCommand.setFavorite(this.favorite)
    : kind = BulkRecordMutationKind.setFavorite,
      folderId = null,
      tagIds = const {};

  const BulkRecordCommand.archive()
    : kind = BulkRecordMutationKind.archive,
      folderId = null,
      tagIds = const {},
      favorite = null;

  const BulkRecordCommand.moveToTrash()
    : kind = BulkRecordMutationKind.moveToTrash,
      folderId = null,
      tagIds = const {},
      favorite = null;

  final BulkRecordMutationKind kind;
  final FolderId? folderId;
  final Set<TagId> tagIds;
  final bool? favorite;
}

List<VaultRecord> applyBulkRecordCommand(
  Iterable<VaultRecord> records,
  BulkRecordCommand command, {
  required DateTime now,
  VaultOrganization? organization,
}) {
  if (command.kind == BulkRecordMutationKind.moveToFolder &&
      command.folderId != null) {
    if (organization == null ||
        !organization.folders.any((folder) => folder.id == command.folderId)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }
  if (command.tagIds.isNotEmpty) {
    final known = organization?.tags.map((tag) => tag.id).toSet() ?? const {};
    if (!known.containsAll(command.tagIds)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }
  return List.unmodifiable(
    records.map((record) {
      final timestamp = now.toUtc();
      return switch (command.kind) {
        BulkRecordMutationKind.moveToFolder => record.copyWith(
          folderId: command.folderId,
          clearFolder: command.folderId == null,
          updatedAt: timestamp,
        ),
        BulkRecordMutationKind.addTags => record.copyWith(
          tagIds: {...record.tagIds, ...command.tagIds},
          updatedAt: timestamp,
        ),
        BulkRecordMutationKind.removeTags => record.copyWith(
          tagIds: record.tagIds.where((tag) => !command.tagIds.contains(tag)),
          updatedAt: timestamp,
        ),
        BulkRecordMutationKind.setFavorite => record.copyWith(
          favorite: command.favorite!,
          updatedAt: timestamp,
        ),
        BulkRecordMutationKind.archive => archiveRecord(record, timestamp),
        BulkRecordMutationKind.moveToTrash => moveRecordToTrash(
          record,
          timestamp,
        ),
      };
    }),
  );
}

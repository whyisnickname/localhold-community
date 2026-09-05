// SPDX-License-Identifier: MPL-2.0

// ignore_for_file: prefer_initializing_formals

import 'document_codec.dart';
import 'document_repository.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';
import 'policies.dart';
import 'repository.dart';
import 'vault_health.dart';

final class EditorDraftSnapshot {
  EditorDraftSnapshot({
    required this.recordId,
    required this.typeId,
    required Iterable<VaultField> fields,
    required this.createdAt,
    this.lifecycle = RecordLifecycle.active,
    this.favorite = false,
    this.pinned = false,
    this.folderId,
    Iterable<TagId> tagIds = const [],
  }) : fields = List.unmodifiable(fields),
       tagIds = Set.unmodifiable(tagIds) {
    if (typeId.isEmpty ||
        typeId.length > 128 ||
        this.fields.length > VaultLimits.maximumFieldsPerRecord ||
        this.fields.map((field) => field.id.value).toSet().length !=
            this.fields.length ||
        this.tagIds.length > VaultLimits.maximumTagsPerRecord) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  factory EditorDraftSnapshot.fromTemplate(
    RecordTypeDefinition template, {
    required DateTime now,
  }) => EditorDraftSnapshot(
    recordId: RecordId.generate(),
    typeId: template.stableId,
    fields: template.fields.map(
      (definition) => VaultField(
        id: FieldId.generate(),
        kind: definition.kind,
        label: definition.defaultLabel,
        value: null,
        definitionId: definition.stableId,
      ),
    ),
    createdAt: now.toUtc(),
  );

  factory EditorDraftSnapshot.fromRecord(VaultRecord record) =>
      EditorDraftSnapshot(
        recordId: record.id,
        typeId: record.typeId,
        fields: record.fields,
        createdAt: record.createdAt,
        lifecycle: record.lifecycle,
        favorite: record.favorite,
        pinned: record.pinned,
        folderId: record.folderId,
        tagIds: record.tagIds,
      );

  final RecordId recordId;
  final String typeId;
  final List<VaultField> fields;
  final DateTime createdAt;
  final RecordLifecycle lifecycle;
  final bool favorite;
  final bool pinned;
  final FolderId? folderId;
  final Set<TagId> tagIds;

  bool get hasUserValue => fields.any((field) => field.hasUserValue);

  EditorDraftSnapshot withFieldValue(FieldId fieldId, Object? value) {
    var found = false;
    final updated = fields
        .map((field) {
          if (field.id != fieldId) return field;
          found = true;
          return _copyField(field, value: value);
        })
        .toList(growable: false);
    if (!found) throw const VaultFailure(VaultFailureCode.objectNotFound);
    return copyWith(fields: updated);
  }

  EditorRemovalPlan planRemoval(FieldId fieldId) {
    final index = fields.indexWhere((field) => field.id == fieldId);
    if (index < 0) throw const VaultFailure(VaultFailureCode.objectNotFound);
    final field = fields[index];
    return EditorRemovalPlan(
      source: this,
      removed: EditorRemovedField(field: field, index: index),
      requiresConfirmation: field.hasUserValue,
    );
  }

  EditorDraftSnapshot restore(EditorRemovedField removed) {
    if (fields.any((field) => field.id == removed.field.id) ||
        removed.index < 0 ||
        removed.index > fields.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final restored = [...fields]..insert(removed.index, removed.field);
    return copyWith(fields: restored);
  }

  VaultRecord materialize({
    required DateTime now,
    int revision = 1,
    RecordLifecycle? lifecycle,
    bool? favorite,
    bool? pinned,
    FolderId? folderId,
    bool clearFolder = false,
    Iterable<TagId>? tagIds,
  }) => VaultRecord(
    id: recordId,
    typeId: typeId,
    fields: fields,
    createdAt: createdAt,
    updatedAt: now.toUtc(),
    revision: revision,
    lifecycle: lifecycle ?? this.lifecycle,
    favorite: favorite ?? this.favorite,
    pinned: pinned ?? this.pinned,
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    tagIds: tagIds ?? this.tagIds,
  );

  String safeDisplayName(RecordTypeDefinition template) {
    return safeDisplayValue(template) ?? template.defaultName;
  }

  String? safeDisplayValue(RecordTypeDefinition template) {
    if (template.stableId != typeId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final definitions = {
      for (final definition in template.fields) definition.stableId: definition,
    };
    for (final field in fields) {
      final definition = definitions[field.definitionId];
      if (definition == null ||
          !definition.displayCandidate ||
          definition.protected ||
          !field.hasUserValue) {
        continue;
      }
      final value = field.value;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  EditorDraftSnapshot copyWith({
    String? typeId,
    Iterable<VaultField>? fields,
    RecordLifecycle? lifecycle,
    bool? favorite,
    bool? pinned,
    FolderId? folderId,
    bool clearFolder = false,
    Iterable<TagId>? tagIds,
  }) => EditorDraftSnapshot(
    recordId: recordId,
    typeId: typeId ?? this.typeId,
    fields: fields ?? this.fields,
    createdAt: createdAt,
    lifecycle: lifecycle ?? this.lifecycle,
    favorite: favorite ?? this.favorite,
    pinned: pinned ?? this.pinned,
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    tagIds: tagIds ?? this.tagIds,
  );

  Map<String, Object?> toJson() => {
    'recordId': recordId.value,
    'typeId': typeId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lifecycle': lifecycle.name,
    'favorite': favorite,
    'pinned': pinned,
    'folderId': folderId?.value,
    'tagIds': tagIds.map((tag) => tag.value).toList(growable: false),
    'fields': fields.map((field) => field.toJson()).toList(growable: false),
  };

  factory EditorDraftSnapshot.fromJson(Map<String, Object?> json) {
    try {
      final rawFields = json['fields']! as List<Object?>;
      return EditorDraftSnapshot(
        recordId: RecordId.parse(json['recordId']! as String),
        typeId: json['typeId']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
        lifecycle: RecordLifecycle.values.byName(
          json['lifecycle'] as String? ?? RecordLifecycle.active.name,
        ),
        favorite: json['favorite'] as bool? ?? false,
        pinned: json['pinned'] as bool? ?? false,
        folderId: switch (json['folderId']) {
          final String value => FolderId.parse(value),
          _ => null,
        },
        tagIds: (json['tagIds'] as List<Object?>? ?? const []).map(
          (value) => TagId.parse(value! as String),
        ),
        fields: rawFields.map((value) {
          final field = Map<String, Object?>.from(
            value! as Map<Object?, Object?>,
          );
          return VaultField(
            id: FieldId.parse(field['id']! as String),
            kind: VaultFieldKind.values.byName(field['kind']! as String),
            label: field['label']! as String,
            value: field['value'],
            definitionId: field['definitionId'] as String?,
            options: Map<String, Object?>.from(
              field['options']! as Map<Object?, Object?>,
            ),
          );
        }),
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }
}

final class EditorRemovedField {
  const EditorRemovedField({required this.field, required this.index});

  final VaultField field;
  final int index;
}

final class EditorRemovalPlan {
  const EditorRemovalPlan({
    required this.source,
    required this.removed,
    required this.requiresConfirmation,
  });

  final EditorDraftSnapshot source;
  final EditorRemovedField removed;
  final bool requiresConfirmation;

  EditorDraftSnapshot apply() {
    final fields = [...source.fields]..removeAt(removed.index);
    return source.copyWith(fields: fields);
  }
}

final class EditorDraftDocument {
  EditorDraftDocument({
    required this.id,
    required this.snapshot,
    required this.updatedAt,
    this.targetRecordId,
    this.baseRecordRevision,
    this.revision = 1,
  }) {
    if (revision < 1 ||
        (targetRecordId == null) != (baseRecordRevision == null) ||
        (baseRecordRevision != null && baseRecordRevision! < 1) ||
        (targetRecordId != null && targetRecordId != snapshot.recordId)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  factory EditorDraftDocument.create({
    required EditorDraftSnapshot snapshot,
    required DateTime now,
    VaultRecord? target,
  }) => EditorDraftDocument(
    id: DraftId.generate(),
    snapshot: snapshot,
    updatedAt: now.toUtc(),
    targetRecordId: target?.id,
    baseRecordRevision: target?.revision,
  );

  final DraftId id;
  final EditorDraftSnapshot snapshot;
  final DateTime updatedAt;
  final RecordId? targetRecordId;
  final int? baseRecordRevision;
  final int revision;

  EditorDraftDocument copyWith({
    DraftId? id,
    EditorDraftSnapshot? snapshot,
    DateTime? updatedAt,
    int? revision,
  }) => EditorDraftDocument(
    id: id ?? this.id,
    snapshot: snapshot ?? this.snapshot,
    updatedAt: updatedAt ?? this.updatedAt,
    targetRecordId: targetRecordId,
    baseRecordRevision: baseRecordRevision,
    revision: revision ?? this.revision,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id.value,
    'snapshot': snapshot.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'targetRecordId': targetRecordId?.value,
    'baseRecordRevision': baseRecordRevision,
    'revision': revision,
  };

  factory EditorDraftDocument.fromJson(Map<String, Object?> json) {
    try {
      if (json['schemaVersion'] != 1) {
        throw const VaultFailure(VaultFailureCode.unsupportedVersion);
      }
      return EditorDraftDocument(
        id: DraftId.parse(json['id']! as String),
        snapshot: EditorDraftSnapshot.fromJson(
          Map<String, Object?>.from(json['snapshot']! as Map<Object?, Object?>),
        ),
        updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
        targetRecordId: switch (json['targetRecordId']) {
          final String value => RecordId.parse(value),
          _ => null,
        },
        baseRecordRevision: json['baseRecordRevision'] as int?,
        revision: json['revision']! as int,
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }
}

final class EditorDraftSaveResult {
  const EditorDraftSaveResult.saved(this.draft) : conflictCopy = null;
  const EditorDraftSaveResult.conflict(this.conflictCopy) : draft = null;

  final EditorDraftDocument? draft;
  final EditorDraftDocument? conflictCopy;
}

final class EncryptedEditorDraftService {
  const EncryptedEditorDraftService({
    required CiphertextRepository repository,
    required PayloadCipher cipher,
    VaultDocumentCodec documents = const VaultDocumentCodec(),
    VaultHealthController? health,
  }) : _repository = repository,
       _cipher = cipher,
       _documents = documents,
       _health = health;

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final VaultDocumentCodec _documents;
  final VaultHealthController? _health;

  Future<EditorDraftSaveResult> create(EditorDraftDocument draft) async {
    _health?.requireWritable();
    if (draft.revision != 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    await _create(draft);
    return EditorDraftSaveResult.saved(draft);
  }

  Future<EditorDraftSaveResult> replace({
    required EditorDraftDocument draft,
    required int expectedRevision,
    required DateTime now,
  }) async {
    _health?.requireWritable();
    final saved = draft.copyWith(
      revision: expectedRevision + 1,
      updatedAt: now.toUtc(),
    );
    try {
      await _repository.replace(
        object: await _encryptedObject(saved),
        expectedRevision: expectedRevision,
      );
      return EditorDraftSaveResult.saved(saved);
    } on VaultFailure catch (failure) {
      if (failure.code != VaultFailureCode.revisionConflict) rethrow;
      final copy = saved.copyWith(
        id: DraftId.generate(),
        revision: 1,
        updatedAt: now.toUtc(),
      );
      await _create(copy);
      return EditorDraftSaveResult.conflict(copy);
    }
  }

  Future<List<EditorDraftDocument>> loadAll() async {
    final result = <EditorDraftDocument>[];
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      codec: _documents,
      health: _health,
    );
    final snapshot = await loader.loadAll();
    for (final encrypted in snapshot.documents) {
      if (encrypted.document.kind != 'editor_draft') continue;
      try {
        final draft = EditorDraftDocument.fromJson(encrypted.document.payload);
        if (draft.id.value != encrypted.object.objectId ||
            draft.revision != encrypted.object.revision) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        result.add(draft);
      } on VaultFailure catch (failure) {
        if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
        await loader.quarantine(
          encrypted.object,
          VaultFailureCode.integrityFailure,
        );
      }
    }
    return List.unmodifiable(result);
  }

  Future<void> discard(EditorDraftDocument draft) async {
    _health?.requireWritable();
    await _repository.remove(
      objectId: draft.id.value,
      expectedRevision: draft.revision,
    );
  }

  Future<void> _create(EditorDraftDocument draft) async {
    await _repository.create(await _encryptedObject(draft));
  }

  Future<EncryptedObject> _encryptedObject(EditorDraftDocument draft) async {
    final plaintext = _documents.encode(
      kind: 'editor_draft',
      payload: draft.toJson(),
    );
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

VaultField _copyField(VaultField source, {required Object? value}) =>
    VaultField(
      id: source.id,
      kind: source.kind,
      label: source.label,
      value: value,
      definitionId: source.definitionId,
      options: source.options,
    );

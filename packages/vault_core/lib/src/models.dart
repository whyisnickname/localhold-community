// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'errors.dart';
import 'identifiers.dart';
import 'policies.dart';

enum VaultFieldKind {
  text,
  secret,
  username,
  email,
  phone,
  url,
  note,
  date,
  time,
  period,
  number,
  money,
  currency,
  boolean,
  choice,
  address,
  totp,
  attachment,
  custom,
}

enum RecordLifecycle { active, archived, trashed }

enum TemplateCategory { accounts, money, personal, technical, custom }

enum TemplateIcon {
  account,
  social,
  email,
  gaming,
  subscription,
  paymentCard,
  bank,
  identity,
  document,
  secureNote,
  software,
  wifi,
  router,
  server,
  database,
  api,
  ssh,
  recovery,
  crypto,
  custom,
}

enum FieldSection { primary, details, advanced }

enum FieldSearchScope { none, standard, protected }

final class FieldDefinition {
  FieldDefinition({
    required this.stableId,
    required this.kind,
    required this.defaultLabel,
    this.protected = false,
    this.section = FieldSection.primary,
    this.displayCandidate = false,
    FieldSearchScope? searchScope,
    this.warningCode,
  }) : searchScope =
           searchScope ??
           (protected
               ? FieldSearchScope.protected
               : FieldSearchScope.standard) {
    if (stableId.isEmpty ||
        stableId.length > 128 ||
        defaultLabel.isEmpty ||
        defaultLabel.length > 256 ||
        (displayCandidate && protected) ||
        (protected && searchScope == FieldSearchScope.standard) ||
        (!protected && searchScope == FieldSearchScope.protected) ||
        (warningCode != null &&
            !RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(warningCode!))) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final String stableId;
  final VaultFieldKind kind;
  final String defaultLabel;
  final bool protected;
  final FieldSection section;
  final bool displayCandidate;
  final FieldSearchScope searchScope;
  final String? warningCode;
}

final class RecordTypeDefinition {
  RecordTypeDefinition({
    required this.stableId,
    required this.defaultName,
    required Iterable<FieldDefinition> fields,
    this.builtIn = true,
    this.category = TemplateCategory.custom,
    this.icon = TemplateIcon.custom,
  }) : fields = List.unmodifiable(fields) {
    if (stableId.isEmpty ||
        stableId.length > 128 ||
        defaultName.isEmpty ||
        defaultName.length > 256 ||
        this.fields.length > VaultLimits.maximumFieldsPerRecord ||
        this.fields.map((field) => field.stableId).toSet().length !=
            this.fields.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final String stableId;
  final String defaultName;
  final List<FieldDefinition> fields;
  final bool builtIn;
  final TemplateCategory category;
  final TemplateIcon icon;
}

abstract final class BuiltInRecordTypes {
  static const account = 'localhold.account.v1';
  static const socialProfile = 'localhold.social_profile.v1';
  static const emailAccount = 'localhold.email_account.v1';
  static const subscription = 'localhold.subscription.v1';
  static const identity = 'localhold.identity.v1';
  static const paymentCard = 'localhold.payment_card.v1';
  static const bankDetails = 'localhold.bank_details.v1';
  static const identityDocument = 'localhold.identity_document.v1';
  static const secureNote = 'localhold.secure_note.v1';
  static const softwareLicense = 'localhold.software_license.v1';
  static const server = 'localhold.server.v1';
  static const database = 'localhold.database.v1';
  static const apiCredential = 'localhold.api_credential.v1';
  static const sshCredential = 'localhold.ssh_credential.v1';
  static const wirelessNetwork = 'localhold.wireless_network.v1';
  static const router = 'localhold.router.v1';
  static const gamingAccount = 'localhold.gaming_account.v1';
  static const cryptoAccount = 'localhold.crypto_account.v1';
  static const recoveryCodes = 'localhold.recovery_codes.v1';
}

final class VaultField {
  VaultField({
    required this.id,
    required this.kind,
    required this.label,
    required this.value,
    this.definitionId,
    Map<String, Object?> options = const {},
  }) : options = Map.unmodifiable(options) {
    if (label.length > 256 ||
        (definitionId != null &&
            !RegExp(r'^[A-Za-z0-9_.-]{1,128}$').hasMatch(definitionId!)) ||
        !_isJsonValue(value, depth: 0) ||
        !_isJsonValue(this.options, depth: 0)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final FieldId id;
  final VaultFieldKind kind;
  final String label;
  final Object? value;
  final String? definitionId;
  final Map<String, Object?> options;

  bool get hasUserValue => switch (value) {
    null => false,
    final String value =>
      kind == VaultFieldKind.secret
          ? value.isNotEmpty
          : value.trim().isNotEmpty,
    final Iterable<Object?> value => value.isNotEmpty,
    final Map<Object?, Object?> value => value.isNotEmpty,
    _ => true,
  };

  Map<String, Object?> toJson() => {
    'id': id.value,
    'kind': kind.name,
    'label': label,
    'value': value,
    'definitionId': definitionId,
    'options': options,
  };

  static bool _isJsonValue(Object? value, {required int depth}) {
    if (depth > 12) return false;
    return switch (value) {
      null || bool() || num() => true,
      final String value =>
        utf8.encode(value).length <= VaultLimits.maximumRecordBytes,
      final List<Object?> value =>
        value.length <= 1024 &&
            value.every((item) => _isJsonValue(item, depth: depth + 1)),
      final Map<String, Object?> value =>
        value.length <= 1024 &&
            value.entries.every(
              (entry) =>
                  entry.key.length <= 256 &&
                  _isJsonValue(entry.value, depth: depth + 1),
            ),
      _ => false,
    };
  }
}

final class VaultRecord {
  VaultRecord({
    required this.id,
    required this.typeId,
    required Iterable<VaultField> fields,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
    this.lifecycle = RecordLifecycle.active,
    this.favorite = false,
    this.pinned = false,
    this.folderId,
    Iterable<TagId> tagIds = const [],
    this.conflictOf,
  }) : fields = List.unmodifiable(fields),
       tagIds = Set.unmodifiable(tagIds) {
    _validate();
  }

  final RecordId id;
  final String typeId;
  final List<VaultField> fields;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final RecordLifecycle lifecycle;
  final bool favorite;
  final bool pinned;
  final FolderId? folderId;
  final Set<TagId> tagIds;
  final RecordId? conflictOf;

  factory VaultRecord.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1 ||
        json['fields'] is! List<Object?> ||
        json['tagIds'] is! List<Object?>) {
      throw const VaultFailure(VaultFailureCode.unsupportedVersion);
    }
    final rawFields = json['fields']! as List<Object?>;
    final rawTags = json['tagIds']! as List<Object?>;
    try {
      return VaultRecord(
        id: RecordId.parse(json['id']! as String),
        typeId: json['typeId']! as String,
        fields: rawFields.map((value) {
          final field = value! as Map<String, Object?>;
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
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
        revision: json['revision']! as int,
        lifecycle: RecordLifecycle.values.byName(json['lifecycle']! as String),
        favorite: json['favorite']! as bool,
        pinned: json['pinned'] as bool? ?? false,
        folderId: switch (json['folderId']) {
          final String value => FolderId.parse(value),
          _ => null,
        },
        tagIds: rawTags.map((value) => TagId.parse(value! as String)),
        conflictOf: switch (json['conflictOf']) {
          final String value => RecordId.parse(value),
          _ => null,
        },
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  void _validate() {
    if (typeId.isEmpty ||
        typeId.length > 128 ||
        revision < 1 ||
        updatedAt.toUtc().isBefore(createdAt.toUtc())) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    if (fields.isEmpty ||
        fields.length > VaultLimits.maximumFieldsPerRecord ||
        !fields.any((field) => field.hasUserValue) ||
        tagIds.length > VaultLimits.maximumTagsPerRecord ||
        tagIds.map((tag) => tag.value).toSet().length != tagIds.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    if (fields.map((field) => field.id.value).toSet().length != fields.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    if (encodedBytes.length > VaultLimits.maximumRecordBytes) {
      throw const VaultFailure(VaultFailureCode.payloadTooLarge);
    }
  }

  List<int> get encodedBytes => utf8.encode(jsonEncode(toJson()));

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id.value,
    'typeId': typeId,
    'fields': fields.map((field) => field.toJson()).toList(growable: false),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'lifecycle': lifecycle.name,
    'favorite': favorite,
    'pinned': pinned,
    'folderId': folderId?.value,
    'tagIds': tagIds.map((tag) => tag.value).toList(growable: false),
    'conflictOf': conflictOf?.value,
  };

  VaultRecord copyWith({
    RecordId? id,
    String? typeId,
    Iterable<VaultField>? fields,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? revision,
    RecordLifecycle? lifecycle,
    bool? favorite,
    bool? pinned,
    FolderId? folderId,
    bool clearFolder = false,
    Iterable<TagId>? tagIds,
    RecordId? conflictOf,
    bool clearConflict = false,
  }) => VaultRecord(
    id: id ?? this.id,
    typeId: typeId ?? this.typeId,
    fields: fields ?? this.fields,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
    lifecycle: lifecycle ?? this.lifecycle,
    favorite: favorite ?? this.favorite,
    pinned: pinned ?? this.pinned,
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    tagIds: tagIds ?? this.tagIds,
    conflictOf: clearConflict ? null : (conflictOf ?? this.conflictOf),
  );
}

final class VaultFolder {
  VaultFolder({required this.id, required this.name, this.parentId}) {
    if (name.trim().isEmpty || name.length > 256) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final FolderId id;
  final String name;
  final FolderId? parentId;
}

final class VaultTag {
  VaultTag({required this.id, required this.name}) {
    if (name.trim().isEmpty || name.length > 256) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final TagId id;
  final String name;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

// SPDX-License-Identifier: MPL-2.0

part of 'database.dart';

// ignore_for_file: type=lint
class $EncryptedObjectsTable extends EncryptedObjects
    with TableInfo<$EncryptedObjectsTable, EncryptedObjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EncryptedObjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _vaultIdMeta = const VerificationMeta(
    'vaultId',
  );
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
    'vault_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectIdMeta = const VerificationMeta(
    'objectId',
  );
  @override
  late final GeneratedColumn<String> objectId = GeneratedColumn<String>(
    'object_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyGenerationIdMeta = const VerificationMeta(
    'keyGenerationId',
  );
  @override
  late final GeneratedColumn<String> keyGenerationId = GeneratedColumn<String>(
    'key_generation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeMeta = const VerificationMeta(
    'envelope',
  );
  @override
  late final GeneratedColumn<Uint8List> envelope = GeneratedColumn<Uint8List>(
    'envelope',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    vaultId,
    objectId,
    revision,
    schemaVersion,
    keyGenerationId,
    envelope,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'encrypted_objects';
  @override
  VerificationContext validateIntegrity(
    Insertable<EncryptedObjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('vault_id')) {
      context.handle(
        _vaultIdMeta,
        vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    if (data.containsKey('object_id')) {
      context.handle(
        _objectIdMeta,
        objectId.isAcceptableOrUnknown(data['object_id']!, _objectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_objectIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('key_generation_id')) {
      context.handle(
        _keyGenerationIdMeta,
        keyGenerationId.isAcceptableOrUnknown(
          data['key_generation_id']!,
          _keyGenerationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_keyGenerationIdMeta);
    }
    if (data.containsKey('envelope')) {
      context.handle(
        _envelopeMeta,
        envelope.isAcceptableOrUnknown(data['envelope']!, _envelopeMeta),
      );
    } else if (isInserting) {
      context.missing(_envelopeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {vaultId, objectId};
  @override
  EncryptedObjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EncryptedObjectRow(
      vaultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_id'],
      )!,
      objectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      keyGenerationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_generation_id'],
      )!,
      envelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}envelope'],
      )!,
    );
  }

  @override
  $EncryptedObjectsTable createAlias(String alias) {
    return $EncryptedObjectsTable(attachedDatabase, alias);
  }
}

class EncryptedObjectRow extends DataClass
    implements Insertable<EncryptedObjectRow> {
  final String vaultId;
  final String objectId;
  final int revision;
  final int schemaVersion;
  final String keyGenerationId;
  final Uint8List envelope;
  const EncryptedObjectRow({
    required this.vaultId,
    required this.objectId,
    required this.revision,
    required this.schemaVersion,
    required this.keyGenerationId,
    required this.envelope,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['vault_id'] = Variable<String>(vaultId);
    map['object_id'] = Variable<String>(objectId);
    map['revision'] = Variable<int>(revision);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['key_generation_id'] = Variable<String>(keyGenerationId);
    map['envelope'] = Variable<Uint8List>(envelope);
    return map;
  }

  EncryptedObjectsCompanion toCompanion(bool nullToAbsent) {
    return EncryptedObjectsCompanion(
      vaultId: Value(vaultId),
      objectId: Value(objectId),
      revision: Value(revision),
      schemaVersion: Value(schemaVersion),
      keyGenerationId: Value(keyGenerationId),
      envelope: Value(envelope),
    );
  }

  factory EncryptedObjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EncryptedObjectRow(
      vaultId: serializer.fromJson<String>(json['vaultId']),
      objectId: serializer.fromJson<String>(json['objectId']),
      revision: serializer.fromJson<int>(json['revision']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      keyGenerationId: serializer.fromJson<String>(json['keyGenerationId']),
      envelope: serializer.fromJson<Uint8List>(json['envelope']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'vaultId': serializer.toJson<String>(vaultId),
      'objectId': serializer.toJson<String>(objectId),
      'revision': serializer.toJson<int>(revision),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'keyGenerationId': serializer.toJson<String>(keyGenerationId),
      'envelope': serializer.toJson<Uint8List>(envelope),
    };
  }

  EncryptedObjectRow copyWith({
    String? vaultId,
    String? objectId,
    int? revision,
    int? schemaVersion,
    String? keyGenerationId,
    Uint8List? envelope,
  }) => EncryptedObjectRow(
    vaultId: vaultId ?? this.vaultId,
    objectId: objectId ?? this.objectId,
    revision: revision ?? this.revision,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    keyGenerationId: keyGenerationId ?? this.keyGenerationId,
    envelope: envelope ?? this.envelope,
  );
  EncryptedObjectRow copyWithCompanion(EncryptedObjectsCompanion data) {
    return EncryptedObjectRow(
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
      objectId: data.objectId.present ? data.objectId.value : this.objectId,
      revision: data.revision.present ? data.revision.value : this.revision,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      keyGenerationId: data.keyGenerationId.present
          ? data.keyGenerationId.value
          : this.keyGenerationId,
      envelope: data.envelope.present ? data.envelope.value : this.envelope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedObjectRow(')
          ..write('vaultId: $vaultId, ')
          ..write('objectId: $objectId, ')
          ..write('revision: $revision, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('keyGenerationId: $keyGenerationId, ')
          ..write('envelope: $envelope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    vaultId,
    objectId,
    revision,
    schemaVersion,
    keyGenerationId,
    $driftBlobEquality.hash(envelope),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EncryptedObjectRow &&
          other.vaultId == this.vaultId &&
          other.objectId == this.objectId &&
          other.revision == this.revision &&
          other.schemaVersion == this.schemaVersion &&
          other.keyGenerationId == this.keyGenerationId &&
          $driftBlobEquality.equals(other.envelope, this.envelope));
}

class EncryptedObjectsCompanion extends UpdateCompanion<EncryptedObjectRow> {
  final Value<String> vaultId;
  final Value<String> objectId;
  final Value<int> revision;
  final Value<int> schemaVersion;
  final Value<String> keyGenerationId;
  final Value<Uint8List> envelope;
  final Value<int> rowid;
  const EncryptedObjectsCompanion({
    this.vaultId = const Value.absent(),
    this.objectId = const Value.absent(),
    this.revision = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.keyGenerationId = const Value.absent(),
    this.envelope = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EncryptedObjectsCompanion.insert({
    required String vaultId,
    required String objectId,
    required int revision,
    required int schemaVersion,
    required String keyGenerationId,
    required Uint8List envelope,
    this.rowid = const Value.absent(),
  }) : vaultId = Value(vaultId),
       objectId = Value(objectId),
       revision = Value(revision),
       schemaVersion = Value(schemaVersion),
       keyGenerationId = Value(keyGenerationId),
       envelope = Value(envelope);
  static Insertable<EncryptedObjectRow> custom({
    Expression<String>? vaultId,
    Expression<String>? objectId,
    Expression<int>? revision,
    Expression<int>? schemaVersion,
    Expression<String>? keyGenerationId,
    Expression<Uint8List>? envelope,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (vaultId != null) 'vault_id': vaultId,
      if (objectId != null) 'object_id': objectId,
      if (revision != null) 'revision': revision,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (keyGenerationId != null) 'key_generation_id': keyGenerationId,
      if (envelope != null) 'envelope': envelope,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EncryptedObjectsCompanion copyWith({
    Value<String>? vaultId,
    Value<String>? objectId,
    Value<int>? revision,
    Value<int>? schemaVersion,
    Value<String>? keyGenerationId,
    Value<Uint8List>? envelope,
    Value<int>? rowid,
  }) {
    return EncryptedObjectsCompanion(
      vaultId: vaultId ?? this.vaultId,
      objectId: objectId ?? this.objectId,
      revision: revision ?? this.revision,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      keyGenerationId: keyGenerationId ?? this.keyGenerationId,
      envelope: envelope ?? this.envelope,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    if (objectId.present) {
      map['object_id'] = Variable<String>(objectId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (keyGenerationId.present) {
      map['key_generation_id'] = Variable<String>(keyGenerationId.value);
    }
    if (envelope.present) {
      map['envelope'] = Variable<Uint8List>(envelope.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedObjectsCompanion(')
          ..write('vaultId: $vaultId, ')
          ..write('objectId: $objectId, ')
          ..write('revision: $revision, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('keyGenerationId: $keyGenerationId, ')
          ..write('envelope: $envelope, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultEnvelopesTable extends VaultEnvelopes
    with TableInfo<$VaultEnvelopesTable, VaultEnvelope> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultEnvelopesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _vaultIdMeta = const VerificationMeta(
    'vaultId',
  );
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
    'vault_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _masterEnvelopeMeta = const VerificationMeta(
    'masterEnvelope',
  );
  @override
  late final GeneratedColumn<Uint8List> masterEnvelope =
      GeneratedColumn<Uint8List>(
        'master_envelope',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _recoveryEnvelopeMeta = const VerificationMeta(
    'recoveryEnvelope',
  );
  @override
  late final GeneratedColumn<Uint8List> recoveryEnvelope =
      GeneratedColumn<Uint8List>(
        'recovery_envelope',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    vaultId,
    masterEnvelope,
    recoveryEnvelope,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_envelopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultEnvelope> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('vault_id')) {
      context.handle(
        _vaultIdMeta,
        vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    if (data.containsKey('master_envelope')) {
      context.handle(
        _masterEnvelopeMeta,
        masterEnvelope.isAcceptableOrUnknown(
          data['master_envelope']!,
          _masterEnvelopeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_masterEnvelopeMeta);
    }
    if (data.containsKey('recovery_envelope')) {
      context.handle(
        _recoveryEnvelopeMeta,
        recoveryEnvelope.isAcceptableOrUnknown(
          data['recovery_envelope']!,
          _recoveryEnvelopeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {vaultId};
  @override
  VaultEnvelope map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultEnvelope(
      vaultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_id'],
      )!,
      masterEnvelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}master_envelope'],
      )!,
      recoveryEnvelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}recovery_envelope'],
      ),
    );
  }

  @override
  $VaultEnvelopesTable createAlias(String alias) {
    return $VaultEnvelopesTable(attachedDatabase, alias);
  }
}

class VaultEnvelope extends DataClass implements Insertable<VaultEnvelope> {
  final String vaultId;
  final Uint8List masterEnvelope;
  final Uint8List? recoveryEnvelope;
  const VaultEnvelope({
    required this.vaultId,
    required this.masterEnvelope,
    this.recoveryEnvelope,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['vault_id'] = Variable<String>(vaultId);
    map['master_envelope'] = Variable<Uint8List>(masterEnvelope);
    if (!nullToAbsent || recoveryEnvelope != null) {
      map['recovery_envelope'] = Variable<Uint8List>(recoveryEnvelope);
    }
    return map;
  }

  VaultEnvelopesCompanion toCompanion(bool nullToAbsent) {
    return VaultEnvelopesCompanion(
      vaultId: Value(vaultId),
      masterEnvelope: Value(masterEnvelope),
      recoveryEnvelope: recoveryEnvelope == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryEnvelope),
    );
  }

  factory VaultEnvelope.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultEnvelope(
      vaultId: serializer.fromJson<String>(json['vaultId']),
      masterEnvelope: serializer.fromJson<Uint8List>(json['masterEnvelope']),
      recoveryEnvelope: serializer.fromJson<Uint8List?>(
        json['recoveryEnvelope'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'vaultId': serializer.toJson<String>(vaultId),
      'masterEnvelope': serializer.toJson<Uint8List>(masterEnvelope),
      'recoveryEnvelope': serializer.toJson<Uint8List?>(recoveryEnvelope),
    };
  }

  VaultEnvelope copyWith({
    String? vaultId,
    Uint8List? masterEnvelope,
    Value<Uint8List?> recoveryEnvelope = const Value.absent(),
  }) => VaultEnvelope(
    vaultId: vaultId ?? this.vaultId,
    masterEnvelope: masterEnvelope ?? this.masterEnvelope,
    recoveryEnvelope: recoveryEnvelope.present
        ? recoveryEnvelope.value
        : this.recoveryEnvelope,
  );
  VaultEnvelope copyWithCompanion(VaultEnvelopesCompanion data) {
    return VaultEnvelope(
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
      masterEnvelope: data.masterEnvelope.present
          ? data.masterEnvelope.value
          : this.masterEnvelope,
      recoveryEnvelope: data.recoveryEnvelope.present
          ? data.recoveryEnvelope.value
          : this.recoveryEnvelope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultEnvelope(')
          ..write('vaultId: $vaultId, ')
          ..write('masterEnvelope: $masterEnvelope, ')
          ..write('recoveryEnvelope: $recoveryEnvelope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    vaultId,
    $driftBlobEquality.hash(masterEnvelope),
    $driftBlobEquality.hash(recoveryEnvelope),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultEnvelope &&
          other.vaultId == this.vaultId &&
          $driftBlobEquality.equals(
            other.masterEnvelope,
            this.masterEnvelope,
          ) &&
          $driftBlobEquality.equals(
            other.recoveryEnvelope,
            this.recoveryEnvelope,
          ));
}

class VaultEnvelopesCompanion extends UpdateCompanion<VaultEnvelope> {
  final Value<String> vaultId;
  final Value<Uint8List> masterEnvelope;
  final Value<Uint8List?> recoveryEnvelope;
  final Value<int> rowid;
  const VaultEnvelopesCompanion({
    this.vaultId = const Value.absent(),
    this.masterEnvelope = const Value.absent(),
    this.recoveryEnvelope = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultEnvelopesCompanion.insert({
    required String vaultId,
    required Uint8List masterEnvelope,
    this.recoveryEnvelope = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vaultId = Value(vaultId),
       masterEnvelope = Value(masterEnvelope);
  static Insertable<VaultEnvelope> custom({
    Expression<String>? vaultId,
    Expression<Uint8List>? masterEnvelope,
    Expression<Uint8List>? recoveryEnvelope,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (vaultId != null) 'vault_id': vaultId,
      if (masterEnvelope != null) 'master_envelope': masterEnvelope,
      if (recoveryEnvelope != null) 'recovery_envelope': recoveryEnvelope,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultEnvelopesCompanion copyWith({
    Value<String>? vaultId,
    Value<Uint8List>? masterEnvelope,
    Value<Uint8List?>? recoveryEnvelope,
    Value<int>? rowid,
  }) {
    return VaultEnvelopesCompanion(
      vaultId: vaultId ?? this.vaultId,
      masterEnvelope: masterEnvelope ?? this.masterEnvelope,
      recoveryEnvelope: recoveryEnvelope ?? this.recoveryEnvelope,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    if (masterEnvelope.present) {
      map['master_envelope'] = Variable<Uint8List>(masterEnvelope.value);
    }
    if (recoveryEnvelope.present) {
      map['recovery_envelope'] = Variable<Uint8List>(recoveryEnvelope.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultEnvelopesCompanion(')
          ..write('vaultId: $vaultId, ')
          ..write('masterEnvelope: $masterEnvelope, ')
          ..write('recoveryEnvelope: $recoveryEnvelope, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuarantinedObjectsTable extends QuarantinedObjects
    with TableInfo<$QuarantinedObjectsTable, QuarantinedObject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuarantinedObjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _vaultIdMeta = const VerificationMeta(
    'vaultId',
  );
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
    'vault_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectIdMeta = const VerificationMeta(
    'objectId',
  );
  @override
  late final GeneratedColumn<String> objectId = GeneratedColumn<String>(
    'object_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyGenerationIdMeta = const VerificationMeta(
    'keyGenerationId',
  );
  @override
  late final GeneratedColumn<String> keyGenerationId = GeneratedColumn<String>(
    'key_generation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeMeta = const VerificationMeta(
    'envelope',
  );
  @override
  late final GeneratedColumn<Uint8List> envelope = GeneratedColumn<Uint8List>(
    'envelope',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonCodeMeta = const VerificationMeta(
    'reasonCode',
  );
  @override
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
    'reason_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    vaultId,
    objectId,
    revision,
    schemaVersion,
    keyGenerationId,
    envelope,
    reasonCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quarantined_objects';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuarantinedObject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('vault_id')) {
      context.handle(
        _vaultIdMeta,
        vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    if (data.containsKey('object_id')) {
      context.handle(
        _objectIdMeta,
        objectId.isAcceptableOrUnknown(data['object_id']!, _objectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_objectIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('key_generation_id')) {
      context.handle(
        _keyGenerationIdMeta,
        keyGenerationId.isAcceptableOrUnknown(
          data['key_generation_id']!,
          _keyGenerationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_keyGenerationIdMeta);
    }
    if (data.containsKey('envelope')) {
      context.handle(
        _envelopeMeta,
        envelope.isAcceptableOrUnknown(data['envelope']!, _envelopeMeta),
      );
    } else if (isInserting) {
      context.missing(_envelopeMeta);
    }
    if (data.containsKey('reason_code')) {
      context.handle(
        _reasonCodeMeta,
        reasonCode.isAcceptableOrUnknown(data['reason_code']!, _reasonCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonCodeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {vaultId, objectId};
  @override
  QuarantinedObject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuarantinedObject(
      vaultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_id'],
      )!,
      objectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      keyGenerationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_generation_id'],
      )!,
      envelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}envelope'],
      )!,
      reasonCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_code'],
      )!,
    );
  }

  @override
  $QuarantinedObjectsTable createAlias(String alias) {
    return $QuarantinedObjectsTable(attachedDatabase, alias);
  }
}

class QuarantinedObject extends DataClass
    implements Insertable<QuarantinedObject> {
  final String vaultId;
  final String objectId;
  final int revision;
  final int schemaVersion;
  final String keyGenerationId;
  final Uint8List envelope;
  final String reasonCode;
  const QuarantinedObject({
    required this.vaultId,
    required this.objectId,
    required this.revision,
    required this.schemaVersion,
    required this.keyGenerationId,
    required this.envelope,
    required this.reasonCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['vault_id'] = Variable<String>(vaultId);
    map['object_id'] = Variable<String>(objectId);
    map['revision'] = Variable<int>(revision);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['key_generation_id'] = Variable<String>(keyGenerationId);
    map['envelope'] = Variable<Uint8List>(envelope);
    map['reason_code'] = Variable<String>(reasonCode);
    return map;
  }

  QuarantinedObjectsCompanion toCompanion(bool nullToAbsent) {
    return QuarantinedObjectsCompanion(
      vaultId: Value(vaultId),
      objectId: Value(objectId),
      revision: Value(revision),
      schemaVersion: Value(schemaVersion),
      keyGenerationId: Value(keyGenerationId),
      envelope: Value(envelope),
      reasonCode: Value(reasonCode),
    );
  }

  factory QuarantinedObject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuarantinedObject(
      vaultId: serializer.fromJson<String>(json['vaultId']),
      objectId: serializer.fromJson<String>(json['objectId']),
      revision: serializer.fromJson<int>(json['revision']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      keyGenerationId: serializer.fromJson<String>(json['keyGenerationId']),
      envelope: serializer.fromJson<Uint8List>(json['envelope']),
      reasonCode: serializer.fromJson<String>(json['reasonCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'vaultId': serializer.toJson<String>(vaultId),
      'objectId': serializer.toJson<String>(objectId),
      'revision': serializer.toJson<int>(revision),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'keyGenerationId': serializer.toJson<String>(keyGenerationId),
      'envelope': serializer.toJson<Uint8List>(envelope),
      'reasonCode': serializer.toJson<String>(reasonCode),
    };
  }

  QuarantinedObject copyWith({
    String? vaultId,
    String? objectId,
    int? revision,
    int? schemaVersion,
    String? keyGenerationId,
    Uint8List? envelope,
    String? reasonCode,
  }) => QuarantinedObject(
    vaultId: vaultId ?? this.vaultId,
    objectId: objectId ?? this.objectId,
    revision: revision ?? this.revision,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    keyGenerationId: keyGenerationId ?? this.keyGenerationId,
    envelope: envelope ?? this.envelope,
    reasonCode: reasonCode ?? this.reasonCode,
  );
  QuarantinedObject copyWithCompanion(QuarantinedObjectsCompanion data) {
    return QuarantinedObject(
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
      objectId: data.objectId.present ? data.objectId.value : this.objectId,
      revision: data.revision.present ? data.revision.value : this.revision,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      keyGenerationId: data.keyGenerationId.present
          ? data.keyGenerationId.value
          : this.keyGenerationId,
      envelope: data.envelope.present ? data.envelope.value : this.envelope,
      reasonCode: data.reasonCode.present
          ? data.reasonCode.value
          : this.reasonCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuarantinedObject(')
          ..write('vaultId: $vaultId, ')
          ..write('objectId: $objectId, ')
          ..write('revision: $revision, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('keyGenerationId: $keyGenerationId, ')
          ..write('envelope: $envelope, ')
          ..write('reasonCode: $reasonCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    vaultId,
    objectId,
    revision,
    schemaVersion,
    keyGenerationId,
    $driftBlobEquality.hash(envelope),
    reasonCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuarantinedObject &&
          other.vaultId == this.vaultId &&
          other.objectId == this.objectId &&
          other.revision == this.revision &&
          other.schemaVersion == this.schemaVersion &&
          other.keyGenerationId == this.keyGenerationId &&
          $driftBlobEquality.equals(other.envelope, this.envelope) &&
          other.reasonCode == this.reasonCode);
}

class QuarantinedObjectsCompanion extends UpdateCompanion<QuarantinedObject> {
  final Value<String> vaultId;
  final Value<String> objectId;
  final Value<int> revision;
  final Value<int> schemaVersion;
  final Value<String> keyGenerationId;
  final Value<Uint8List> envelope;
  final Value<String> reasonCode;
  final Value<int> rowid;
  const QuarantinedObjectsCompanion({
    this.vaultId = const Value.absent(),
    this.objectId = const Value.absent(),
    this.revision = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.keyGenerationId = const Value.absent(),
    this.envelope = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuarantinedObjectsCompanion.insert({
    required String vaultId,
    required String objectId,
    required int revision,
    required int schemaVersion,
    required String keyGenerationId,
    required Uint8List envelope,
    required String reasonCode,
    this.rowid = const Value.absent(),
  }) : vaultId = Value(vaultId),
       objectId = Value(objectId),
       revision = Value(revision),
       schemaVersion = Value(schemaVersion),
       keyGenerationId = Value(keyGenerationId),
       envelope = Value(envelope),
       reasonCode = Value(reasonCode);
  static Insertable<QuarantinedObject> custom({
    Expression<String>? vaultId,
    Expression<String>? objectId,
    Expression<int>? revision,
    Expression<int>? schemaVersion,
    Expression<String>? keyGenerationId,
    Expression<Uint8List>? envelope,
    Expression<String>? reasonCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (vaultId != null) 'vault_id': vaultId,
      if (objectId != null) 'object_id': objectId,
      if (revision != null) 'revision': revision,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (keyGenerationId != null) 'key_generation_id': keyGenerationId,
      if (envelope != null) 'envelope': envelope,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuarantinedObjectsCompanion copyWith({
    Value<String>? vaultId,
    Value<String>? objectId,
    Value<int>? revision,
    Value<int>? schemaVersion,
    Value<String>? keyGenerationId,
    Value<Uint8List>? envelope,
    Value<String>? reasonCode,
    Value<int>? rowid,
  }) {
    return QuarantinedObjectsCompanion(
      vaultId: vaultId ?? this.vaultId,
      objectId: objectId ?? this.objectId,
      revision: revision ?? this.revision,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      keyGenerationId: keyGenerationId ?? this.keyGenerationId,
      envelope: envelope ?? this.envelope,
      reasonCode: reasonCode ?? this.reasonCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    if (objectId.present) {
      map['object_id'] = Variable<String>(objectId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (keyGenerationId.present) {
      map['key_generation_id'] = Variable<String>(keyGenerationId.value);
    }
    if (envelope.present) {
      map['envelope'] = Variable<Uint8List>(envelope.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuarantinedObjectsCompanion(')
          ..write('vaultId: $vaultId, ')
          ..write('objectId: $objectId, ')
          ..write('revision: $revision, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('keyGenerationId: $keyGenerationId, ')
          ..write('envelope: $envelope, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnlockThrottlesTable extends UnlockThrottles
    with TableInfo<$UnlockThrottlesTable, UnlockThrottle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnlockThrottlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _vaultIdMeta = const VerificationMeta(
    'vaultId',
  );
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
    'vault_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedAttemptsMeta = const VerificationMeta(
    'failedAttempts',
  );
  @override
  late final GeneratedColumn<int> failedAttempts = GeneratedColumn<int>(
    'failed_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cooldownUntilMillisMeta =
      const VerificationMeta('cooldownUntilMillis');
  @override
  late final GeneratedColumn<int> cooldownUntilMillis = GeneratedColumn<int>(
    'cooldown_until_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    vaultId,
    failedAttempts,
    cooldownUntilMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unlock_throttles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnlockThrottle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('vault_id')) {
      context.handle(
        _vaultIdMeta,
        vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    if (data.containsKey('failed_attempts')) {
      context.handle(
        _failedAttemptsMeta,
        failedAttempts.isAcceptableOrUnknown(
          data['failed_attempts']!,
          _failedAttemptsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_failedAttemptsMeta);
    }
    if (data.containsKey('cooldown_until_millis')) {
      context.handle(
        _cooldownUntilMillisMeta,
        cooldownUntilMillis.isAcceptableOrUnknown(
          data['cooldown_until_millis']!,
          _cooldownUntilMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {vaultId};
  @override
  UnlockThrottle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnlockThrottle(
      vaultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_id'],
      )!,
      failedAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_attempts'],
      )!,
      cooldownUntilMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cooldown_until_millis'],
      ),
    );
  }

  @override
  $UnlockThrottlesTable createAlias(String alias) {
    return $UnlockThrottlesTable(attachedDatabase, alias);
  }
}

class UnlockThrottle extends DataClass implements Insertable<UnlockThrottle> {
  final String vaultId;
  final int failedAttempts;
  final int? cooldownUntilMillis;
  const UnlockThrottle({
    required this.vaultId,
    required this.failedAttempts,
    this.cooldownUntilMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['vault_id'] = Variable<String>(vaultId);
    map['failed_attempts'] = Variable<int>(failedAttempts);
    if (!nullToAbsent || cooldownUntilMillis != null) {
      map['cooldown_until_millis'] = Variable<int>(cooldownUntilMillis);
    }
    return map;
  }

  UnlockThrottlesCompanion toCompanion(bool nullToAbsent) {
    return UnlockThrottlesCompanion(
      vaultId: Value(vaultId),
      failedAttempts: Value(failedAttempts),
      cooldownUntilMillis: cooldownUntilMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(cooldownUntilMillis),
    );
  }

  factory UnlockThrottle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnlockThrottle(
      vaultId: serializer.fromJson<String>(json['vaultId']),
      failedAttempts: serializer.fromJson<int>(json['failedAttempts']),
      cooldownUntilMillis: serializer.fromJson<int?>(
        json['cooldownUntilMillis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'vaultId': serializer.toJson<String>(vaultId),
      'failedAttempts': serializer.toJson<int>(failedAttempts),
      'cooldownUntilMillis': serializer.toJson<int?>(cooldownUntilMillis),
    };
  }

  UnlockThrottle copyWith({
    String? vaultId,
    int? failedAttempts,
    Value<int?> cooldownUntilMillis = const Value.absent(),
  }) => UnlockThrottle(
    vaultId: vaultId ?? this.vaultId,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    cooldownUntilMillis: cooldownUntilMillis.present
        ? cooldownUntilMillis.value
        : this.cooldownUntilMillis,
  );
  UnlockThrottle copyWithCompanion(UnlockThrottlesCompanion data) {
    return UnlockThrottle(
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
      failedAttempts: data.failedAttempts.present
          ? data.failedAttempts.value
          : this.failedAttempts,
      cooldownUntilMillis: data.cooldownUntilMillis.present
          ? data.cooldownUntilMillis.value
          : this.cooldownUntilMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnlockThrottle(')
          ..write('vaultId: $vaultId, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('cooldownUntilMillis: $cooldownUntilMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(vaultId, failedAttempts, cooldownUntilMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnlockThrottle &&
          other.vaultId == this.vaultId &&
          other.failedAttempts == this.failedAttempts &&
          other.cooldownUntilMillis == this.cooldownUntilMillis);
}

class UnlockThrottlesCompanion extends UpdateCompanion<UnlockThrottle> {
  final Value<String> vaultId;
  final Value<int> failedAttempts;
  final Value<int?> cooldownUntilMillis;
  final Value<int> rowid;
  const UnlockThrottlesCompanion({
    this.vaultId = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.cooldownUntilMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnlockThrottlesCompanion.insert({
    required String vaultId,
    required int failedAttempts,
    this.cooldownUntilMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vaultId = Value(vaultId),
       failedAttempts = Value(failedAttempts);
  static Insertable<UnlockThrottle> custom({
    Expression<String>? vaultId,
    Expression<int>? failedAttempts,
    Expression<int>? cooldownUntilMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (vaultId != null) 'vault_id': vaultId,
      if (failedAttempts != null) 'failed_attempts': failedAttempts,
      if (cooldownUntilMillis != null)
        'cooldown_until_millis': cooldownUntilMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnlockThrottlesCompanion copyWith({
    Value<String>? vaultId,
    Value<int>? failedAttempts,
    Value<int?>? cooldownUntilMillis,
    Value<int>? rowid,
  }) {
    return UnlockThrottlesCompanion(
      vaultId: vaultId ?? this.vaultId,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      cooldownUntilMillis: cooldownUntilMillis ?? this.cooldownUntilMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    if (failedAttempts.present) {
      map['failed_attempts'] = Variable<int>(failedAttempts.value);
    }
    if (cooldownUntilMillis.present) {
      map['cooldown_until_millis'] = Variable<int>(cooldownUntilMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnlockThrottlesCompanion(')
          ..write('vaultId: $vaultId, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('cooldownUntilMillis: $cooldownUntilMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MigrationJournalsTable extends MigrationJournals
    with TableInfo<$MigrationJournalsTable, MigrationJournal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MigrationJournalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sourceVersionMeta = const VerificationMeta(
    'sourceVersion',
  );
  @override
  late final GeneratedColumn<int> sourceVersion = GeneratedColumn<int>(
    'source_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetVersionMeta = const VerificationMeta(
    'targetVersion',
  );
  @override
  late final GeneratedColumn<int> targetVersion = GeneratedColumn<int>(
    'target_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stagingIdMeta = const VerificationMeta(
    'stagingId',
  );
  @override
  late final GeneratedColumn<String> stagingId = GeneratedColumn<String>(
    'staging_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceVersion,
    targetVersion,
    phase,
    stagingId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'migration_journals';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigrationJournal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_version')) {
      context.handle(
        _sourceVersionMeta,
        sourceVersion.isAcceptableOrUnknown(
          data['source_version']!,
          _sourceVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceVersionMeta);
    }
    if (data.containsKey('target_version')) {
      context.handle(
        _targetVersionMeta,
        targetVersion.isAcceptableOrUnknown(
          data['target_version']!,
          _targetVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetVersionMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('staging_id')) {
      context.handle(
        _stagingIdMeta,
        stagingId.isAcceptableOrUnknown(data['staging_id']!, _stagingIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MigrationJournal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigrationJournal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_version'],
      )!,
      targetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_version'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      stagingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staging_id'],
      ),
    );
  }

  @override
  $MigrationJournalsTable createAlias(String alias) {
    return $MigrationJournalsTable(attachedDatabase, alias);
  }
}

class MigrationJournal extends DataClass
    implements Insertable<MigrationJournal> {
  final int id;
  final int sourceVersion;
  final int targetVersion;
  final String phase;
  final String? stagingId;
  const MigrationJournal({
    required this.id,
    required this.sourceVersion,
    required this.targetVersion,
    required this.phase,
    this.stagingId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_version'] = Variable<int>(sourceVersion);
    map['target_version'] = Variable<int>(targetVersion);
    map['phase'] = Variable<String>(phase);
    if (!nullToAbsent || stagingId != null) {
      map['staging_id'] = Variable<String>(stagingId);
    }
    return map;
  }

  MigrationJournalsCompanion toCompanion(bool nullToAbsent) {
    return MigrationJournalsCompanion(
      id: Value(id),
      sourceVersion: Value(sourceVersion),
      targetVersion: Value(targetVersion),
      phase: Value(phase),
      stagingId: stagingId == null && nullToAbsent
          ? const Value.absent()
          : Value(stagingId),
    );
  }

  factory MigrationJournal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigrationJournal(
      id: serializer.fromJson<int>(json['id']),
      sourceVersion: serializer.fromJson<int>(json['sourceVersion']),
      targetVersion: serializer.fromJson<int>(json['targetVersion']),
      phase: serializer.fromJson<String>(json['phase']),
      stagingId: serializer.fromJson<String?>(json['stagingId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceVersion': serializer.toJson<int>(sourceVersion),
      'targetVersion': serializer.toJson<int>(targetVersion),
      'phase': serializer.toJson<String>(phase),
      'stagingId': serializer.toJson<String?>(stagingId),
    };
  }

  MigrationJournal copyWith({
    int? id,
    int? sourceVersion,
    int? targetVersion,
    String? phase,
    Value<String?> stagingId = const Value.absent(),
  }) => MigrationJournal(
    id: id ?? this.id,
    sourceVersion: sourceVersion ?? this.sourceVersion,
    targetVersion: targetVersion ?? this.targetVersion,
    phase: phase ?? this.phase,
    stagingId: stagingId.present ? stagingId.value : this.stagingId,
  );
  MigrationJournal copyWithCompanion(MigrationJournalsCompanion data) {
    return MigrationJournal(
      id: data.id.present ? data.id.value : this.id,
      sourceVersion: data.sourceVersion.present
          ? data.sourceVersion.value
          : this.sourceVersion,
      targetVersion: data.targetVersion.present
          ? data.targetVersion.value
          : this.targetVersion,
      phase: data.phase.present ? data.phase.value : this.phase,
      stagingId: data.stagingId.present ? data.stagingId.value : this.stagingId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MigrationJournal(')
          ..write('id: $id, ')
          ..write('sourceVersion: $sourceVersion, ')
          ..write('targetVersion: $targetVersion, ')
          ..write('phase: $phase, ')
          ..write('stagingId: $stagingId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sourceVersion, targetVersion, phase, stagingId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigrationJournal &&
          other.id == this.id &&
          other.sourceVersion == this.sourceVersion &&
          other.targetVersion == this.targetVersion &&
          other.phase == this.phase &&
          other.stagingId == this.stagingId);
}

class MigrationJournalsCompanion extends UpdateCompanion<MigrationJournal> {
  final Value<int> id;
  final Value<int> sourceVersion;
  final Value<int> targetVersion;
  final Value<String> phase;
  final Value<String?> stagingId;
  const MigrationJournalsCompanion({
    this.id = const Value.absent(),
    this.sourceVersion = const Value.absent(),
    this.targetVersion = const Value.absent(),
    this.phase = const Value.absent(),
    this.stagingId = const Value.absent(),
  });
  MigrationJournalsCompanion.insert({
    this.id = const Value.absent(),
    required int sourceVersion,
    required int targetVersion,
    required String phase,
    this.stagingId = const Value.absent(),
  }) : sourceVersion = Value(sourceVersion),
       targetVersion = Value(targetVersion),
       phase = Value(phase);
  static Insertable<MigrationJournal> custom({
    Expression<int>? id,
    Expression<int>? sourceVersion,
    Expression<int>? targetVersion,
    Expression<String>? phase,
    Expression<String>? stagingId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceVersion != null) 'source_version': sourceVersion,
      if (targetVersion != null) 'target_version': targetVersion,
      if (phase != null) 'phase': phase,
      if (stagingId != null) 'staging_id': stagingId,
    });
  }

  MigrationJournalsCompanion copyWith({
    Value<int>? id,
    Value<int>? sourceVersion,
    Value<int>? targetVersion,
    Value<String>? phase,
    Value<String?>? stagingId,
  }) {
    return MigrationJournalsCompanion(
      id: id ?? this.id,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      targetVersion: targetVersion ?? this.targetVersion,
      phase: phase ?? this.phase,
      stagingId: stagingId ?? this.stagingId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceVersion.present) {
      map['source_version'] = Variable<int>(sourceVersion.value);
    }
    if (targetVersion.present) {
      map['target_version'] = Variable<int>(targetVersion.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (stagingId.present) {
      map['staging_id'] = Variable<String>(stagingId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MigrationJournalsCompanion(')
          ..write('id: $id, ')
          ..write('sourceVersion: $sourceVersion, ')
          ..write('targetVersion: $targetVersion, ')
          ..write('phase: $phase, ')
          ..write('stagingId: $stagingId')
          ..write(')'))
        .toString();
  }
}

class $VaultSelectionsTable extends VaultSelections
    with TableInfo<$VaultSelectionsTable, VaultSelection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultSelectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _vaultIdMeta = const VerificationMeta(
    'vaultId',
  );
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
    'vault_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, vaultId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_selections';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultSelection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('vault_id')) {
      context.handle(
        _vaultIdMeta,
        vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultSelection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultSelection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      vaultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_id'],
      )!,
    );
  }

  @override
  $VaultSelectionsTable createAlias(String alias) {
    return $VaultSelectionsTable(attachedDatabase, alias);
  }
}

class VaultSelection extends DataClass implements Insertable<VaultSelection> {
  final int id;
  final String vaultId;
  const VaultSelection({required this.id, required this.vaultId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['vault_id'] = Variable<String>(vaultId);
    return map;
  }

  VaultSelectionsCompanion toCompanion(bool nullToAbsent) {
    return VaultSelectionsCompanion(id: Value(id), vaultId: Value(vaultId));
  }

  factory VaultSelection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultSelection(
      id: serializer.fromJson<int>(json['id']),
      vaultId: serializer.fromJson<String>(json['vaultId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'vaultId': serializer.toJson<String>(vaultId),
    };
  }

  VaultSelection copyWith({int? id, String? vaultId}) =>
      VaultSelection(id: id ?? this.id, vaultId: vaultId ?? this.vaultId);
  VaultSelection copyWithCompanion(VaultSelectionsCompanion data) {
    return VaultSelection(
      id: data.id.present ? data.id.value : this.id,
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultSelection(')
          ..write('id: $id, ')
          ..write('vaultId: $vaultId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, vaultId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultSelection &&
          other.id == this.id &&
          other.vaultId == this.vaultId);
}

class VaultSelectionsCompanion extends UpdateCompanion<VaultSelection> {
  final Value<int> id;
  final Value<String> vaultId;
  const VaultSelectionsCompanion({
    this.id = const Value.absent(),
    this.vaultId = const Value.absent(),
  });
  VaultSelectionsCompanion.insert({
    this.id = const Value.absent(),
    required String vaultId,
  }) : vaultId = Value(vaultId);
  static Insertable<VaultSelection> custom({
    Expression<int>? id,
    Expression<String>? vaultId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vaultId != null) 'vault_id': vaultId,
    });
  }

  VaultSelectionsCompanion copyWith({Value<int>? id, Value<String>? vaultId}) {
    return VaultSelectionsCompanion(
      id: id ?? this.id,
      vaultId: vaultId ?? this.vaultId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultSelectionsCompanion(')
          ..write('id: $id, ')
          ..write('vaultId: $vaultId')
          ..write(')'))
        .toString();
  }
}

class $VaultUnlockEntriesTable extends VaultUnlockEntries
    with TableInfo<$VaultUnlockEntriesTable, VaultUnlockEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultUnlockEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _vaultIdMeta = const VerificationMeta(
    'vaultId',
  );
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
    'vault_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 22,
      maxTextLength: 22,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicLabelMeta = const VerificationMeta(
    'publicLabel',
  );
  @override
  late final GeneratedColumn<String> publicLabel = GeneratedColumn<String>(
    'public_label',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [vaultId, ordinal, publicLabel];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_unlock_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultUnlockEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('vault_id')) {
      context.handle(
        _vaultIdMeta,
        vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('public_label')) {
      context.handle(
        _publicLabelMeta,
        publicLabel.isAcceptableOrUnknown(
          data['public_label']!,
          _publicLabelMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {vaultId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ordinal},
  ];
  @override
  VaultUnlockEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultUnlockEntryRow(
      vaultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      publicLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_label'],
      ),
    );
  }

  @override
  $VaultUnlockEntriesTable createAlias(String alias) {
    return $VaultUnlockEntriesTable(attachedDatabase, alias);
  }
}

class VaultUnlockEntryRow extends DataClass
    implements Insertable<VaultUnlockEntryRow> {
  final String vaultId;
  final int ordinal;
  final String? publicLabel;
  const VaultUnlockEntryRow({
    required this.vaultId,
    required this.ordinal,
    this.publicLabel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['vault_id'] = Variable<String>(vaultId);
    map['ordinal'] = Variable<int>(ordinal);
    if (!nullToAbsent || publicLabel != null) {
      map['public_label'] = Variable<String>(publicLabel);
    }
    return map;
  }

  VaultUnlockEntriesCompanion toCompanion(bool nullToAbsent) {
    return VaultUnlockEntriesCompanion(
      vaultId: Value(vaultId),
      ordinal: Value(ordinal),
      publicLabel: publicLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(publicLabel),
    );
  }

  factory VaultUnlockEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultUnlockEntryRow(
      vaultId: serializer.fromJson<String>(json['vaultId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      publicLabel: serializer.fromJson<String?>(json['publicLabel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'vaultId': serializer.toJson<String>(vaultId),
      'ordinal': serializer.toJson<int>(ordinal),
      'publicLabel': serializer.toJson<String?>(publicLabel),
    };
  }

  VaultUnlockEntryRow copyWith({
    String? vaultId,
    int? ordinal,
    Value<String?> publicLabel = const Value.absent(),
  }) => VaultUnlockEntryRow(
    vaultId: vaultId ?? this.vaultId,
    ordinal: ordinal ?? this.ordinal,
    publicLabel: publicLabel.present ? publicLabel.value : this.publicLabel,
  );
  VaultUnlockEntryRow copyWithCompanion(VaultUnlockEntriesCompanion data) {
    return VaultUnlockEntryRow(
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      publicLabel: data.publicLabel.present
          ? data.publicLabel.value
          : this.publicLabel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultUnlockEntryRow(')
          ..write('vaultId: $vaultId, ')
          ..write('ordinal: $ordinal, ')
          ..write('publicLabel: $publicLabel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(vaultId, ordinal, publicLabel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultUnlockEntryRow &&
          other.vaultId == this.vaultId &&
          other.ordinal == this.ordinal &&
          other.publicLabel == this.publicLabel);
}

class VaultUnlockEntriesCompanion extends UpdateCompanion<VaultUnlockEntryRow> {
  final Value<String> vaultId;
  final Value<int> ordinal;
  final Value<String?> publicLabel;
  final Value<int> rowid;
  const VaultUnlockEntriesCompanion({
    this.vaultId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.publicLabel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultUnlockEntriesCompanion.insert({
    required String vaultId,
    required int ordinal,
    this.publicLabel = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vaultId = Value(vaultId),
       ordinal = Value(ordinal);
  static Insertable<VaultUnlockEntryRow> custom({
    Expression<String>? vaultId,
    Expression<int>? ordinal,
    Expression<String>? publicLabel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (vaultId != null) 'vault_id': vaultId,
      if (ordinal != null) 'ordinal': ordinal,
      if (publicLabel != null) 'public_label': publicLabel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultUnlockEntriesCompanion copyWith({
    Value<String>? vaultId,
    Value<int>? ordinal,
    Value<String?>? publicLabel,
    Value<int>? rowid,
  }) {
    return VaultUnlockEntriesCompanion(
      vaultId: vaultId ?? this.vaultId,
      ordinal: ordinal ?? this.ordinal,
      publicLabel: publicLabel ?? this.publicLabel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (publicLabel.present) {
      map['public_label'] = Variable<String>(publicLabel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultUnlockEntriesCompanion(')
          ..write('vaultId: $vaultId, ')
          ..write('ordinal: $ordinal, ')
          ..write('publicLabel: $publicLabel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalholdVaultDatabase extends GeneratedDatabase {
  _$LocalholdVaultDatabase(QueryExecutor e) : super(e);
  $LocalholdVaultDatabaseManager get managers =>
      $LocalholdVaultDatabaseManager(this);
  late final $EncryptedObjectsTable encryptedObjects = $EncryptedObjectsTable(
    this,
  );
  late final $VaultEnvelopesTable vaultEnvelopes = $VaultEnvelopesTable(this);
  late final $QuarantinedObjectsTable quarantinedObjects =
      $QuarantinedObjectsTable(this);
  late final $UnlockThrottlesTable unlockThrottles = $UnlockThrottlesTable(
    this,
  );
  late final $MigrationJournalsTable migrationJournals =
      $MigrationJournalsTable(this);
  late final $VaultSelectionsTable vaultSelections = $VaultSelectionsTable(
    this,
  );
  late final $VaultUnlockEntriesTable vaultUnlockEntries =
      $VaultUnlockEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    encryptedObjects,
    vaultEnvelopes,
    quarantinedObjects,
    unlockThrottles,
    migrationJournals,
    vaultSelections,
    vaultUnlockEntries,
  ];
}

typedef $$EncryptedObjectsTableCreateCompanionBuilder =
    EncryptedObjectsCompanion Function({
      required String vaultId,
      required String objectId,
      required int revision,
      required int schemaVersion,
      required String keyGenerationId,
      required Uint8List envelope,
      Value<int> rowid,
    });
typedef $$EncryptedObjectsTableUpdateCompanionBuilder =
    EncryptedObjectsCompanion Function({
      Value<String> vaultId,
      Value<String> objectId,
      Value<int> revision,
      Value<int> schemaVersion,
      Value<String> keyGenerationId,
      Value<Uint8List> envelope,
      Value<int> rowid,
    });

class $$EncryptedObjectsTableFilterComposer
    extends Composer<_$LocalholdVaultDatabase, $EncryptedObjectsTable> {
  $$EncryptedObjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyGenerationId => $composableBuilder(
    column: $table.keyGenerationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EncryptedObjectsTableOrderingComposer
    extends Composer<_$LocalholdVaultDatabase, $EncryptedObjectsTable> {
  $$EncryptedObjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyGenerationId => $composableBuilder(
    column: $table.keyGenerationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EncryptedObjectsTableAnnotationComposer
    extends Composer<_$LocalholdVaultDatabase, $EncryptedObjectsTable> {
  $$EncryptedObjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);

  GeneratedColumn<String> get objectId =>
      $composableBuilder(column: $table.objectId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keyGenerationId => $composableBuilder(
    column: $table.keyGenerationId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get envelope =>
      $composableBuilder(column: $table.envelope, builder: (column) => column);
}

class $$EncryptedObjectsTableTableManager
    extends
        RootTableManager<
          _$LocalholdVaultDatabase,
          $EncryptedObjectsTable,
          EncryptedObjectRow,
          $$EncryptedObjectsTableFilterComposer,
          $$EncryptedObjectsTableOrderingComposer,
          $$EncryptedObjectsTableAnnotationComposer,
          $$EncryptedObjectsTableCreateCompanionBuilder,
          $$EncryptedObjectsTableUpdateCompanionBuilder,
          (
            EncryptedObjectRow,
            BaseReferences<
              _$LocalholdVaultDatabase,
              $EncryptedObjectsTable,
              EncryptedObjectRow
            >,
          ),
          EncryptedObjectRow,
          PrefetchHooks Function()
        > {
  $$EncryptedObjectsTableTableManager(
    _$LocalholdVaultDatabase db,
    $EncryptedObjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EncryptedObjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EncryptedObjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EncryptedObjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> vaultId = const Value.absent(),
                Value<String> objectId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> keyGenerationId = const Value.absent(),
                Value<Uint8List> envelope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EncryptedObjectsCompanion(
                vaultId: vaultId,
                objectId: objectId,
                revision: revision,
                schemaVersion: schemaVersion,
                keyGenerationId: keyGenerationId,
                envelope: envelope,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String vaultId,
                required String objectId,
                required int revision,
                required int schemaVersion,
                required String keyGenerationId,
                required Uint8List envelope,
                Value<int> rowid = const Value.absent(),
              }) => EncryptedObjectsCompanion.insert(
                vaultId: vaultId,
                objectId: objectId,
                revision: revision,
                schemaVersion: schemaVersion,
                keyGenerationId: keyGenerationId,
                envelope: envelope,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EncryptedObjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalholdVaultDatabase,
      $EncryptedObjectsTable,
      EncryptedObjectRow,
      $$EncryptedObjectsTableFilterComposer,
      $$EncryptedObjectsTableOrderingComposer,
      $$EncryptedObjectsTableAnnotationComposer,
      $$EncryptedObjectsTableCreateCompanionBuilder,
      $$EncryptedObjectsTableUpdateCompanionBuilder,
      (
        EncryptedObjectRow,
        BaseReferences<
          _$LocalholdVaultDatabase,
          $EncryptedObjectsTable,
          EncryptedObjectRow
        >,
      ),
      EncryptedObjectRow,
      PrefetchHooks Function()
    >;
typedef $$VaultEnvelopesTableCreateCompanionBuilder =
    VaultEnvelopesCompanion Function({
      required String vaultId,
      required Uint8List masterEnvelope,
      Value<Uint8List?> recoveryEnvelope,
      Value<int> rowid,
    });
typedef $$VaultEnvelopesTableUpdateCompanionBuilder =
    VaultEnvelopesCompanion Function({
      Value<String> vaultId,
      Value<Uint8List> masterEnvelope,
      Value<Uint8List?> recoveryEnvelope,
      Value<int> rowid,
    });

class $$VaultEnvelopesTableFilterComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultEnvelopesTable> {
  $$VaultEnvelopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get masterEnvelope => $composableBuilder(
    column: $table.masterEnvelope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get recoveryEnvelope => $composableBuilder(
    column: $table.recoveryEnvelope,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultEnvelopesTableOrderingComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultEnvelopesTable> {
  $$VaultEnvelopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get masterEnvelope => $composableBuilder(
    column: $table.masterEnvelope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get recoveryEnvelope => $composableBuilder(
    column: $table.recoveryEnvelope,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultEnvelopesTableAnnotationComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultEnvelopesTable> {
  $$VaultEnvelopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);

  GeneratedColumn<Uint8List> get masterEnvelope => $composableBuilder(
    column: $table.masterEnvelope,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get recoveryEnvelope => $composableBuilder(
    column: $table.recoveryEnvelope,
    builder: (column) => column,
  );
}

class $$VaultEnvelopesTableTableManager
    extends
        RootTableManager<
          _$LocalholdVaultDatabase,
          $VaultEnvelopesTable,
          VaultEnvelope,
          $$VaultEnvelopesTableFilterComposer,
          $$VaultEnvelopesTableOrderingComposer,
          $$VaultEnvelopesTableAnnotationComposer,
          $$VaultEnvelopesTableCreateCompanionBuilder,
          $$VaultEnvelopesTableUpdateCompanionBuilder,
          (
            VaultEnvelope,
            BaseReferences<
              _$LocalholdVaultDatabase,
              $VaultEnvelopesTable,
              VaultEnvelope
            >,
          ),
          VaultEnvelope,
          PrefetchHooks Function()
        > {
  $$VaultEnvelopesTableTableManager(
    _$LocalholdVaultDatabase db,
    $VaultEnvelopesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultEnvelopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultEnvelopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultEnvelopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> vaultId = const Value.absent(),
                Value<Uint8List> masterEnvelope = const Value.absent(),
                Value<Uint8List?> recoveryEnvelope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultEnvelopesCompanion(
                vaultId: vaultId,
                masterEnvelope: masterEnvelope,
                recoveryEnvelope: recoveryEnvelope,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String vaultId,
                required Uint8List masterEnvelope,
                Value<Uint8List?> recoveryEnvelope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultEnvelopesCompanion.insert(
                vaultId: vaultId,
                masterEnvelope: masterEnvelope,
                recoveryEnvelope: recoveryEnvelope,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultEnvelopesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalholdVaultDatabase,
      $VaultEnvelopesTable,
      VaultEnvelope,
      $$VaultEnvelopesTableFilterComposer,
      $$VaultEnvelopesTableOrderingComposer,
      $$VaultEnvelopesTableAnnotationComposer,
      $$VaultEnvelopesTableCreateCompanionBuilder,
      $$VaultEnvelopesTableUpdateCompanionBuilder,
      (
        VaultEnvelope,
        BaseReferences<
          _$LocalholdVaultDatabase,
          $VaultEnvelopesTable,
          VaultEnvelope
        >,
      ),
      VaultEnvelope,
      PrefetchHooks Function()
    >;
typedef $$QuarantinedObjectsTableCreateCompanionBuilder =
    QuarantinedObjectsCompanion Function({
      required String vaultId,
      required String objectId,
      required int revision,
      required int schemaVersion,
      required String keyGenerationId,
      required Uint8List envelope,
      required String reasonCode,
      Value<int> rowid,
    });
typedef $$QuarantinedObjectsTableUpdateCompanionBuilder =
    QuarantinedObjectsCompanion Function({
      Value<String> vaultId,
      Value<String> objectId,
      Value<int> revision,
      Value<int> schemaVersion,
      Value<String> keyGenerationId,
      Value<Uint8List> envelope,
      Value<String> reasonCode,
      Value<int> rowid,
    });

class $$QuarantinedObjectsTableFilterComposer
    extends Composer<_$LocalholdVaultDatabase, $QuarantinedObjectsTable> {
  $$QuarantinedObjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyGenerationId => $composableBuilder(
    column: $table.keyGenerationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuarantinedObjectsTableOrderingComposer
    extends Composer<_$LocalholdVaultDatabase, $QuarantinedObjectsTable> {
  $$QuarantinedObjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyGenerationId => $composableBuilder(
    column: $table.keyGenerationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuarantinedObjectsTableAnnotationComposer
    extends Composer<_$LocalholdVaultDatabase, $QuarantinedObjectsTable> {
  $$QuarantinedObjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);

  GeneratedColumn<String> get objectId =>
      $composableBuilder(column: $table.objectId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keyGenerationId => $composableBuilder(
    column: $table.keyGenerationId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get envelope =>
      $composableBuilder(column: $table.envelope, builder: (column) => column);

  GeneratedColumn<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => column,
  );
}

class $$QuarantinedObjectsTableTableManager
    extends
        RootTableManager<
          _$LocalholdVaultDatabase,
          $QuarantinedObjectsTable,
          QuarantinedObject,
          $$QuarantinedObjectsTableFilterComposer,
          $$QuarantinedObjectsTableOrderingComposer,
          $$QuarantinedObjectsTableAnnotationComposer,
          $$QuarantinedObjectsTableCreateCompanionBuilder,
          $$QuarantinedObjectsTableUpdateCompanionBuilder,
          (
            QuarantinedObject,
            BaseReferences<
              _$LocalholdVaultDatabase,
              $QuarantinedObjectsTable,
              QuarantinedObject
            >,
          ),
          QuarantinedObject,
          PrefetchHooks Function()
        > {
  $$QuarantinedObjectsTableTableManager(
    _$LocalholdVaultDatabase db,
    $QuarantinedObjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuarantinedObjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuarantinedObjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuarantinedObjectsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> vaultId = const Value.absent(),
                Value<String> objectId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> keyGenerationId = const Value.absent(),
                Value<Uint8List> envelope = const Value.absent(),
                Value<String> reasonCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuarantinedObjectsCompanion(
                vaultId: vaultId,
                objectId: objectId,
                revision: revision,
                schemaVersion: schemaVersion,
                keyGenerationId: keyGenerationId,
                envelope: envelope,
                reasonCode: reasonCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String vaultId,
                required String objectId,
                required int revision,
                required int schemaVersion,
                required String keyGenerationId,
                required Uint8List envelope,
                required String reasonCode,
                Value<int> rowid = const Value.absent(),
              }) => QuarantinedObjectsCompanion.insert(
                vaultId: vaultId,
                objectId: objectId,
                revision: revision,
                schemaVersion: schemaVersion,
                keyGenerationId: keyGenerationId,
                envelope: envelope,
                reasonCode: reasonCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuarantinedObjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalholdVaultDatabase,
      $QuarantinedObjectsTable,
      QuarantinedObject,
      $$QuarantinedObjectsTableFilterComposer,
      $$QuarantinedObjectsTableOrderingComposer,
      $$QuarantinedObjectsTableAnnotationComposer,
      $$QuarantinedObjectsTableCreateCompanionBuilder,
      $$QuarantinedObjectsTableUpdateCompanionBuilder,
      (
        QuarantinedObject,
        BaseReferences<
          _$LocalholdVaultDatabase,
          $QuarantinedObjectsTable,
          QuarantinedObject
        >,
      ),
      QuarantinedObject,
      PrefetchHooks Function()
    >;
typedef $$UnlockThrottlesTableCreateCompanionBuilder =
    UnlockThrottlesCompanion Function({
      required String vaultId,
      required int failedAttempts,
      Value<int?> cooldownUntilMillis,
      Value<int> rowid,
    });
typedef $$UnlockThrottlesTableUpdateCompanionBuilder =
    UnlockThrottlesCompanion Function({
      Value<String> vaultId,
      Value<int> failedAttempts,
      Value<int?> cooldownUntilMillis,
      Value<int> rowid,
    });

class $$UnlockThrottlesTableFilterComposer
    extends Composer<_$LocalholdVaultDatabase, $UnlockThrottlesTable> {
  $$UnlockThrottlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cooldownUntilMillis => $composableBuilder(
    column: $table.cooldownUntilMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UnlockThrottlesTableOrderingComposer
    extends Composer<_$LocalholdVaultDatabase, $UnlockThrottlesTable> {
  $$UnlockThrottlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cooldownUntilMillis => $composableBuilder(
    column: $table.cooldownUntilMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnlockThrottlesTableAnnotationComposer
    extends Composer<_$LocalholdVaultDatabase, $UnlockThrottlesTable> {
  $$UnlockThrottlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);

  GeneratedColumn<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cooldownUntilMillis => $composableBuilder(
    column: $table.cooldownUntilMillis,
    builder: (column) => column,
  );
}

class $$UnlockThrottlesTableTableManager
    extends
        RootTableManager<
          _$LocalholdVaultDatabase,
          $UnlockThrottlesTable,
          UnlockThrottle,
          $$UnlockThrottlesTableFilterComposer,
          $$UnlockThrottlesTableOrderingComposer,
          $$UnlockThrottlesTableAnnotationComposer,
          $$UnlockThrottlesTableCreateCompanionBuilder,
          $$UnlockThrottlesTableUpdateCompanionBuilder,
          (
            UnlockThrottle,
            BaseReferences<
              _$LocalholdVaultDatabase,
              $UnlockThrottlesTable,
              UnlockThrottle
            >,
          ),
          UnlockThrottle,
          PrefetchHooks Function()
        > {
  $$UnlockThrottlesTableTableManager(
    _$LocalholdVaultDatabase db,
    $UnlockThrottlesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnlockThrottlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnlockThrottlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnlockThrottlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> vaultId = const Value.absent(),
                Value<int> failedAttempts = const Value.absent(),
                Value<int?> cooldownUntilMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnlockThrottlesCompanion(
                vaultId: vaultId,
                failedAttempts: failedAttempts,
                cooldownUntilMillis: cooldownUntilMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String vaultId,
                required int failedAttempts,
                Value<int?> cooldownUntilMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnlockThrottlesCompanion.insert(
                vaultId: vaultId,
                failedAttempts: failedAttempts,
                cooldownUntilMillis: cooldownUntilMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UnlockThrottlesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalholdVaultDatabase,
      $UnlockThrottlesTable,
      UnlockThrottle,
      $$UnlockThrottlesTableFilterComposer,
      $$UnlockThrottlesTableOrderingComposer,
      $$UnlockThrottlesTableAnnotationComposer,
      $$UnlockThrottlesTableCreateCompanionBuilder,
      $$UnlockThrottlesTableUpdateCompanionBuilder,
      (
        UnlockThrottle,
        BaseReferences<
          _$LocalholdVaultDatabase,
          $UnlockThrottlesTable,
          UnlockThrottle
        >,
      ),
      UnlockThrottle,
      PrefetchHooks Function()
    >;
typedef $$MigrationJournalsTableCreateCompanionBuilder =
    MigrationJournalsCompanion Function({
      Value<int> id,
      required int sourceVersion,
      required int targetVersion,
      required String phase,
      Value<String?> stagingId,
    });
typedef $$MigrationJournalsTableUpdateCompanionBuilder =
    MigrationJournalsCompanion Function({
      Value<int> id,
      Value<int> sourceVersion,
      Value<int> targetVersion,
      Value<String> phase,
      Value<String?> stagingId,
    });

class $$MigrationJournalsTableFilterComposer
    extends Composer<_$LocalholdVaultDatabase, $MigrationJournalsTable> {
  $$MigrationJournalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetVersion => $composableBuilder(
    column: $table.targetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stagingId => $composableBuilder(
    column: $table.stagingId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MigrationJournalsTableOrderingComposer
    extends Composer<_$LocalholdVaultDatabase, $MigrationJournalsTable> {
  $$MigrationJournalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetVersion => $composableBuilder(
    column: $table.targetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stagingId => $composableBuilder(
    column: $table.stagingId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MigrationJournalsTableAnnotationComposer
    extends Composer<_$LocalholdVaultDatabase, $MigrationJournalsTable> {
  $$MigrationJournalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetVersion => $composableBuilder(
    column: $table.targetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get stagingId =>
      $composableBuilder(column: $table.stagingId, builder: (column) => column);
}

class $$MigrationJournalsTableTableManager
    extends
        RootTableManager<
          _$LocalholdVaultDatabase,
          $MigrationJournalsTable,
          MigrationJournal,
          $$MigrationJournalsTableFilterComposer,
          $$MigrationJournalsTableOrderingComposer,
          $$MigrationJournalsTableAnnotationComposer,
          $$MigrationJournalsTableCreateCompanionBuilder,
          $$MigrationJournalsTableUpdateCompanionBuilder,
          (
            MigrationJournal,
            BaseReferences<
              _$LocalholdVaultDatabase,
              $MigrationJournalsTable,
              MigrationJournal
            >,
          ),
          MigrationJournal,
          PrefetchHooks Function()
        > {
  $$MigrationJournalsTableTableManager(
    _$LocalholdVaultDatabase db,
    $MigrationJournalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MigrationJournalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MigrationJournalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MigrationJournalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sourceVersion = const Value.absent(),
                Value<int> targetVersion = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String?> stagingId = const Value.absent(),
              }) => MigrationJournalsCompanion(
                id: id,
                sourceVersion: sourceVersion,
                targetVersion: targetVersion,
                phase: phase,
                stagingId: stagingId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sourceVersion,
                required int targetVersion,
                required String phase,
                Value<String?> stagingId = const Value.absent(),
              }) => MigrationJournalsCompanion.insert(
                id: id,
                sourceVersion: sourceVersion,
                targetVersion: targetVersion,
                phase: phase,
                stagingId: stagingId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MigrationJournalsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalholdVaultDatabase,
      $MigrationJournalsTable,
      MigrationJournal,
      $$MigrationJournalsTableFilterComposer,
      $$MigrationJournalsTableOrderingComposer,
      $$MigrationJournalsTableAnnotationComposer,
      $$MigrationJournalsTableCreateCompanionBuilder,
      $$MigrationJournalsTableUpdateCompanionBuilder,
      (
        MigrationJournal,
        BaseReferences<
          _$LocalholdVaultDatabase,
          $MigrationJournalsTable,
          MigrationJournal
        >,
      ),
      MigrationJournal,
      PrefetchHooks Function()
    >;
typedef $$VaultSelectionsTableCreateCompanionBuilder =
    VaultSelectionsCompanion Function({Value<int> id, required String vaultId});
typedef $$VaultSelectionsTableUpdateCompanionBuilder =
    VaultSelectionsCompanion Function({Value<int> id, Value<String> vaultId});

class $$VaultSelectionsTableFilterComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultSelectionsTable> {
  $$VaultSelectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultSelectionsTableOrderingComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultSelectionsTable> {
  $$VaultSelectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultSelectionsTableAnnotationComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultSelectionsTable> {
  $$VaultSelectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);
}

class $$VaultSelectionsTableTableManager
    extends
        RootTableManager<
          _$LocalholdVaultDatabase,
          $VaultSelectionsTable,
          VaultSelection,
          $$VaultSelectionsTableFilterComposer,
          $$VaultSelectionsTableOrderingComposer,
          $$VaultSelectionsTableAnnotationComposer,
          $$VaultSelectionsTableCreateCompanionBuilder,
          $$VaultSelectionsTableUpdateCompanionBuilder,
          (
            VaultSelection,
            BaseReferences<
              _$LocalholdVaultDatabase,
              $VaultSelectionsTable,
              VaultSelection
            >,
          ),
          VaultSelection,
          PrefetchHooks Function()
        > {
  $$VaultSelectionsTableTableManager(
    _$LocalholdVaultDatabase db,
    $VaultSelectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultSelectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultSelectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultSelectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> vaultId = const Value.absent(),
          }) => VaultSelectionsCompanion(id: id, vaultId: vaultId),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String vaultId,
          }) => VaultSelectionsCompanion.insert(id: id, vaultId: vaultId),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultSelectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalholdVaultDatabase,
      $VaultSelectionsTable,
      VaultSelection,
      $$VaultSelectionsTableFilterComposer,
      $$VaultSelectionsTableOrderingComposer,
      $$VaultSelectionsTableAnnotationComposer,
      $$VaultSelectionsTableCreateCompanionBuilder,
      $$VaultSelectionsTableUpdateCompanionBuilder,
      (
        VaultSelection,
        BaseReferences<
          _$LocalholdVaultDatabase,
          $VaultSelectionsTable,
          VaultSelection
        >,
      ),
      VaultSelection,
      PrefetchHooks Function()
    >;
typedef $$VaultUnlockEntriesTableCreateCompanionBuilder =
    VaultUnlockEntriesCompanion Function({
      required String vaultId,
      required int ordinal,
      Value<String?> publicLabel,
      Value<int> rowid,
    });
typedef $$VaultUnlockEntriesTableUpdateCompanionBuilder =
    VaultUnlockEntriesCompanion Function({
      Value<String> vaultId,
      Value<int> ordinal,
      Value<String?> publicLabel,
      Value<int> rowid,
    });

class $$VaultUnlockEntriesTableFilterComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultUnlockEntriesTable> {
  $$VaultUnlockEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicLabel => $composableBuilder(
    column: $table.publicLabel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultUnlockEntriesTableOrderingComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultUnlockEntriesTable> {
  $$VaultUnlockEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicLabel => $composableBuilder(
    column: $table.publicLabel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultUnlockEntriesTableAnnotationComposer
    extends Composer<_$LocalholdVaultDatabase, $VaultUnlockEntriesTable> {
  $$VaultUnlockEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get publicLabel => $composableBuilder(
    column: $table.publicLabel,
    builder: (column) => column,
  );
}

class $$VaultUnlockEntriesTableTableManager
    extends
        RootTableManager<
          _$LocalholdVaultDatabase,
          $VaultUnlockEntriesTable,
          VaultUnlockEntryRow,
          $$VaultUnlockEntriesTableFilterComposer,
          $$VaultUnlockEntriesTableOrderingComposer,
          $$VaultUnlockEntriesTableAnnotationComposer,
          $$VaultUnlockEntriesTableCreateCompanionBuilder,
          $$VaultUnlockEntriesTableUpdateCompanionBuilder,
          (
            VaultUnlockEntryRow,
            BaseReferences<
              _$LocalholdVaultDatabase,
              $VaultUnlockEntriesTable,
              VaultUnlockEntryRow
            >,
          ),
          VaultUnlockEntryRow,
          PrefetchHooks Function()
        > {
  $$VaultUnlockEntriesTableTableManager(
    _$LocalholdVaultDatabase db,
    $VaultUnlockEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultUnlockEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultUnlockEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultUnlockEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> vaultId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String?> publicLabel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultUnlockEntriesCompanion(
                vaultId: vaultId,
                ordinal: ordinal,
                publicLabel: publicLabel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String vaultId,
                required int ordinal,
                Value<String?> publicLabel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultUnlockEntriesCompanion.insert(
                vaultId: vaultId,
                ordinal: ordinal,
                publicLabel: publicLabel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultUnlockEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalholdVaultDatabase,
      $VaultUnlockEntriesTable,
      VaultUnlockEntryRow,
      $$VaultUnlockEntriesTableFilterComposer,
      $$VaultUnlockEntriesTableOrderingComposer,
      $$VaultUnlockEntriesTableAnnotationComposer,
      $$VaultUnlockEntriesTableCreateCompanionBuilder,
      $$VaultUnlockEntriesTableUpdateCompanionBuilder,
      (
        VaultUnlockEntryRow,
        BaseReferences<
          _$LocalholdVaultDatabase,
          $VaultUnlockEntriesTable,
          VaultUnlockEntryRow
        >,
      ),
      VaultUnlockEntryRow,
      PrefetchHooks Function()
    >;

class $LocalholdVaultDatabaseManager {
  final _$LocalholdVaultDatabase _db;
  $LocalholdVaultDatabaseManager(this._db);
  $$EncryptedObjectsTableTableManager get encryptedObjects =>
      $$EncryptedObjectsTableTableManager(_db, _db.encryptedObjects);
  $$VaultEnvelopesTableTableManager get vaultEnvelopes =>
      $$VaultEnvelopesTableTableManager(_db, _db.vaultEnvelopes);
  $$QuarantinedObjectsTableTableManager get quarantinedObjects =>
      $$QuarantinedObjectsTableTableManager(_db, _db.quarantinedObjects);
  $$UnlockThrottlesTableTableManager get unlockThrottles =>
      $$UnlockThrottlesTableTableManager(_db, _db.unlockThrottles);
  $$MigrationJournalsTableTableManager get migrationJournals =>
      $$MigrationJournalsTableTableManager(_db, _db.migrationJournals);
  $$VaultSelectionsTableTableManager get vaultSelections =>
      $$VaultSelectionsTableTableManager(_db, _db.vaultSelections);
  $$VaultUnlockEntriesTableTableManager get vaultUnlockEntries =>
      $$VaultUnlockEntriesTableTableManager(_db, _db.vaultUnlockEntries);
}

// SPDX-License-Identifier: MPL-2.0

import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('EncryptedObjectRow')
class EncryptedObjects extends Table {
  TextColumn get vaultId => text().withLength(min: 22, max: 22)();
  TextColumn get objectId => text().withLength(min: 22, max: 22)();
  IntColumn get revision => integer()();
  IntColumn get schemaVersion => integer()();
  TextColumn get keyGenerationId => text().withLength(min: 22, max: 128)();
  BlobColumn get envelope => blob()();

  @override
  Set<Column<Object>> get primaryKey => {vaultId, objectId};
}

class VaultEnvelopes extends Table {
  TextColumn get vaultId => text().withLength(min: 22, max: 22)();
  BlobColumn get masterEnvelope => blob()();
  BlobColumn get recoveryEnvelope => blob().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {vaultId};
}

class QuarantinedObjects extends Table {
  TextColumn get vaultId => text().withLength(min: 22, max: 22)();
  TextColumn get objectId => text().withLength(min: 22, max: 22)();
  IntColumn get revision => integer()();
  IntColumn get schemaVersion => integer()();
  TextColumn get keyGenerationId => text().withLength(min: 22, max: 128)();
  BlobColumn get envelope => blob()();
  TextColumn get reasonCode => text().withLength(min: 1, max: 64)();

  @override
  Set<Column<Object>> get primaryKey => {vaultId, objectId};
}

class UnlockThrottles extends Table {
  TextColumn get vaultId => text().withLength(min: 22, max: 22)();
  IntColumn get failedAttempts => integer()();
  IntColumn get cooldownUntilMillis => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {vaultId};
}

class MigrationJournals extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get sourceVersion => integer()();
  IntColumn get targetVersion => integer()();
  TextColumn get phase => text().withLength(min: 1, max: 32)();
  TextColumn get stagingId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class VaultSelections extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get vaultId => text().withLength(min: 22, max: 22)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    EncryptedObjects,
    VaultEnvelopes,
    QuarantinedObjects,
    UnlockThrottles,
    MigrationJournals,
    VaultSelections,
  ],
)
class LocalholdVaultDatabase extends _$LocalholdVaultDatabase {
  LocalholdVaultDatabase(super.executor, {this.isReadOnly = false});

  final bool isReadOnly;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (isReadOnly) return;
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = FULL');
      await customStatement('PRAGMA wal_autocheckpoint = 256');
      await customStatement('PRAGMA secure_delete = ON');
    },
  );
}

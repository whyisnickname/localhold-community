// SPDX-License-Identifier: MPL-2.0

import 'package:drift/drift.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:sqlite3/common.dart';

import 'database.dart';
import 'sqlite_failure.dart';

final class DriftCiphertextRepository implements CiphertextRepository {
  const DriftCiphertextRepository(this._database, {required this._vaultId});

  final LocalholdVaultDatabase _database;
  final VaultId _vaultId;

  @override
  Future<void> create(EncryptedObject object) async {
    try {
      await _database
          .into(_database.encryptedObjects)
          .insert(
            EncryptedObjectsCompanion.insert(
              vaultId: _vaultId.value,
              objectId: object.objectId,
              revision: object.revision,
              schemaVersion: object.schemaVersion,
              keyGenerationId: object.keyGenerationId,
              envelope: Uint8List.fromList(object.envelope),
            ),
          );
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error, constraintAsConflict: true);
    }
  }

  @override
  Future<EncryptedObject?> read(String objectId) async {
    try {
      final query = _database.select(_database.encryptedObjects)
        ..where(
          (row) =>
              row.vaultId.equals(_vaultId.value) &
              row.objectId.equals(objectId),
        );
      final row = await query.getSingleOrNull();
      return row == null ? null : _map(row);
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<List<EncryptedObject>> readAll() async {
    try {
      return List.unmodifiable(
        (await (_database.select(
          _database.encryptedObjects,
        )..where((row) => row.vaultId.equals(_vaultId.value))).get()).map(_map),
      );
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Stream<List<EncryptedObject>> watchAll() async* {
    try {
      final query = _database.select(_database.encryptedObjects)
        ..where((row) => row.vaultId.equals(_vaultId.value));
      await for (final rows in query.watch()) {
        yield List.unmodifiable(rows.map(_map));
      }
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> remove({
    required String objectId,
    required int expectedRevision,
  }) async {
    try {
      final affected =
          await (_database.delete(_database.encryptedObjects)..where(
                (row) =>
                    row.vaultId.equals(_vaultId.value) &
                    row.objectId.equals(objectId) &
                    row.revision.equals(expectedRevision),
              ))
              .go();
      if (affected != 1) {
        throw const VaultFailure(VaultFailureCode.revisionConflict);
      }
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> replace({
    required EncryptedObject object,
    required int expectedRevision,
  }) async {
    try {
      final affected =
          await (_database.update(_database.encryptedObjects)..where(
                (row) =>
                    row.vaultId.equals(_vaultId.value) &
                    row.objectId.equals(object.objectId) &
                    row.revision.equals(expectedRevision),
              ))
              .write(
                EncryptedObjectsCompanion(
                  revision: Value(object.revision),
                  schemaVersion: Value(object.schemaVersion),
                  keyGenerationId: Value(object.keyGenerationId),
                  envelope: Value(Uint8List.fromList(object.envelope)),
                ),
              );
      if (affected != 1) {
        throw const VaultFailure(VaultFailureCode.revisionConflict);
      }
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> quarantine({
    required String objectId,
    required int expectedRevision,
    required VaultFailureCode reason,
  }) async {
    try {
      await _database.transaction(() async {
        final query = _database.select(_database.encryptedObjects)
          ..where(
            (row) =>
                row.vaultId.equals(_vaultId.value) &
                row.objectId.equals(objectId) &
                row.revision.equals(expectedRevision),
          );
        final row = await query.getSingleOrNull();
        if (row == null) {
          throw const VaultFailure(VaultFailureCode.revisionConflict);
        }
        await _database
            .into(_database.quarantinedObjects)
            .insertOnConflictUpdate(
              QuarantinedObjectsCompanion.insert(
                vaultId: _vaultId.value,
                objectId: row.objectId,
                revision: row.revision,
                schemaVersion: row.schemaVersion,
                keyGenerationId: row.keyGenerationId,
                envelope: Uint8List.fromList(row.envelope),
                reasonCode: reason.name,
              ),
            );
        final removed =
            await (_database.delete(_database.encryptedObjects)..where(
                  (item) =>
                      item.vaultId.equals(_vaultId.value) &
                      item.objectId.equals(objectId) &
                      item.revision.equals(expectedRevision),
                ))
                .go();
        if (removed != 1) {
          throw const VaultFailure(VaultFailureCode.revisionConflict);
        }
      });
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  EncryptedObject _map(EncryptedObjectRow row) => EncryptedObject(
    objectId: row.objectId,
    revision: row.revision,
    schemaVersion: row.schemaVersion,
    keyGenerationId: row.keyGenerationId,
    envelope: Uint8List.fromList(row.envelope),
  );
}

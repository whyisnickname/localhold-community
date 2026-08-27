// SPDX-License-Identifier: MPL-2.0

import 'package:drift/drift.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:sqlite3/common.dart';

import 'database.dart';
import 'sqlite_failure.dart';

final class DriftVaultSelectionStore implements VaultSelectionStore {
  const DriftVaultSelectionStore(this._database);

  final LocalholdVaultDatabase _database;

  @override
  Future<void> clearIfSelected(VaultId id) async {
    try {
      await (_database.delete(
        _database.vaultSelections,
      )..where((row) => row.id.equals(1) & row.vaultId.equals(id.value))).go();
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<VaultId?> readLastSelected() async {
    try {
      final row = await (_database.select(
        _database.vaultSelections,
      )..where((value) => value.id.equals(1))).getSingleOrNull();
      return row == null ? null : VaultId.parse(row.vaultId);
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> select(VaultId id) async {
    try {
      await _database
          .into(_database.vaultSelections)
          .insertOnConflictUpdate(
            VaultSelectionsCompanion.insert(vaultId: id.value),
          );
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }
}

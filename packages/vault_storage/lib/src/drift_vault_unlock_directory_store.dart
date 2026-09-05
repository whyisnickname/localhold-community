// SPDX-License-Identifier: MPL-2.0

import 'package:drift/drift.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:sqlite3/common.dart';

import 'database.dart';
import 'sqlite_failure.dart';

final class DriftVaultUnlockDirectoryStore
    implements VaultUnlockDirectoryStore {
  const DriftVaultUnlockDirectoryStore(this._database);

  final LocalholdVaultDatabase _database;

  @override
  Future<List<VaultUnlockEntry>> list() async {
    try {
      final rows = await (_database.select(
        _database.vaultUnlockEntries,
      )..orderBy([(row) => OrderingTerm.asc(row.ordinal)])).get();
      return List.unmodifiable(rows.map(_entry));
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<VaultUnlockEntry> register(VaultId id, {String? publicLabel}) async {
    final validated = VaultUnlockEntry(
      vaultId: id,
      ordinal: 1,
      publicLabel: publicLabel,
    );
    try {
      return await _database.transaction(() async {
        final current = await list();
        final existing = current
            .where((entry) => entry.vaultId == id)
            .firstOrNull;
        if (existing != null) return existing;
        final ordinal = current.isEmpty
            ? 1
            : current
                      .map((entry) => entry.ordinal)
                      .reduce((a, b) => a > b ? a : b) +
                  1;
        await _database
            .into(_database.vaultUnlockEntries)
            .insert(
              VaultUnlockEntriesCompanion.insert(
                vaultId: id.value,
                ordinal: ordinal,
                publicLabel: Value(validated.publicLabel),
              ),
            );
        return VaultUnlockEntry(
          vaultId: id,
          ordinal: ordinal,
          publicLabel: validated.publicLabel,
        );
      });
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> updatePublicLabel(VaultId id, String? publicLabel) async {
    VaultUnlockEntry(vaultId: id, ordinal: 1, publicLabel: publicLabel);
    try {
      final changed =
          await (_database.update(
            _database.vaultUnlockEntries,
          )..where((row) => row.vaultId.equals(id.value))).write(
            VaultUnlockEntriesCompanion(publicLabel: Value(publicLabel)),
          );
      if (changed != 1) {
        throw const VaultFailure(VaultFailureCode.objectNotFound);
      }
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> remove(VaultId id) async {
    try {
      await (_database.delete(
        _database.vaultUnlockEntries,
      )..where((row) => row.vaultId.equals(id.value))).go();
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  VaultUnlockEntry _entry(VaultUnlockEntryRow row) => VaultUnlockEntry(
    vaultId: VaultId.parse(row.vaultId),
    ordinal: row.ordinal,
    publicLabel: row.publicLabel,
  );
}

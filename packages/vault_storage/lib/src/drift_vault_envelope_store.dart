// SPDX-License-Identifier: MPL-2.0

import 'package:drift/drift.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_native/localhold_vault_native.dart';
import 'package:sqlite3/common.dart';

import 'database.dart';
import 'sqlite_failure.dart';

final class DriftVaultEnvelopeStore implements VaultEnvelopeStore {
  const DriftVaultEnvelopeStore(this._database);

  final LocalholdVaultDatabase _database;

  @override
  Future<void> createMaster(VaultId vaultId, Uint8List envelope) async {
    try {
      final existing = await _row(vaultId);
      if (existing != null) {
        throw const VaultFailure(VaultFailureCode.revisionConflict);
      }
      await _database
          .into(_database.vaultEnvelopes)
          .insert(
            VaultEnvelopesCompanion.insert(
              vaultId: vaultId.value,
              masterEnvelope: Uint8List.fromList(envelope),
            ),
          );
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error, constraintAsConflict: true);
    }
  }

  @override
  Future<Uint8List?> readMaster(VaultId vaultId) async {
    try {
      final row = await _row(vaultId);
      return row == null ? null : Uint8List.fromList(row.masterEnvelope);
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<Uint8List?> readRecovery(VaultId vaultId) async {
    try {
      final value = (await _row(vaultId))?.recoveryEnvelope;
      return value == null ? null : Uint8List.fromList(value);
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> replaceMaster(VaultId vaultId, Uint8List envelope) async {
    try {
      final affected =
          await (_database.update(
            _database.vaultEnvelopes,
          )..where((row) => row.vaultId.equals(vaultId.value))).write(
            VaultEnvelopesCompanion(
              masterEnvelope: Value(Uint8List.fromList(envelope)),
            ),
          );
      if (affected != 1) {
        throw const VaultFailure(VaultFailureCode.objectNotFound);
      }
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> replaceRecovery(VaultId vaultId, Uint8List envelope) async {
    try {
      final affected =
          await (_database.update(
            _database.vaultEnvelopes,
          )..where((row) => row.vaultId.equals(vaultId.value))).write(
            VaultEnvelopesCompanion(
              recoveryEnvelope: Value(Uint8List.fromList(envelope)),
            ),
          );
      if (affected != 1) {
        throw const VaultFailure(VaultFailureCode.objectNotFound);
      }
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  Future<VaultEnvelope?> _row(VaultId vaultId) => (_database.select(
    _database.vaultEnvelopes,
  )..where((row) => row.vaultId.equals(vaultId.value))).getSingleOrNull();
}

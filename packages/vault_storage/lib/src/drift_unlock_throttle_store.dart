// SPDX-License-Identifier: MPL-2.0

import 'package:drift/drift.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:sqlite3/common.dart';

import 'database.dart';
import 'sqlite_failure.dart';

final class DriftUnlockThrottleStore implements UnlockThrottleStore {
  DriftUnlockThrottleStore(this._database);

  final LocalholdVaultDatabase _database;
  final Map<String, UnlockThrottleState> _readOnlyOverlay = {};

  @override
  Future<void> clear(String vaultId) async {
    if (_database.isReadOnly) {
      _readOnlyOverlay[vaultId] = const UnlockThrottleState(failedAttempts: 0);
      return;
    }
    try {
      await (_database.delete(
        _database.unlockThrottles,
      )..where((row) => row.vaultId.equals(vaultId))).go();
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<UnlockThrottleState> read(String vaultId) async {
    final overlay = _readOnlyOverlay[vaultId];
    if (overlay != null) return overlay;
    try {
      final query = _database.select(_database.unlockThrottles)
        ..where((row) => row.vaultId.equals(vaultId));
      final row = await query.getSingleOrNull();
      return row == null
          ? const UnlockThrottleState(failedAttempts: 0)
          : UnlockThrottleState(
              failedAttempts: row.failedAttempts,
              cooldownUntil: row.cooldownUntilMillis == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      row.cooldownUntilMillis!,
                      isUtc: true,
                    ),
            );
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }

  @override
  Future<void> write(String vaultId, UnlockThrottleState state) async {
    if (_database.isReadOnly) {
      _readOnlyOverlay[vaultId] = state;
      return;
    }
    try {
      await _database
          .into(_database.unlockThrottles)
          .insertOnConflictUpdate(
            UnlockThrottlesCompanion.insert(
              vaultId: vaultId,
              failedAttempts: state.failedAttempts,
              cooldownUntilMillis: Value(
                state.cooldownUntil?.toUtc().millisecondsSinceEpoch,
              ),
            ),
          );
    } on SqliteException catch (error) {
      throw mapSqliteFailure(error);
    }
  }
}

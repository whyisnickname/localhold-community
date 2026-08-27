// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:sqlite3/common.dart';

VaultFailure mapSqliteFailure(
  SqliteException error, {
  bool constraintAsConflict = false,
}) => VaultFailure(switch (error.resultCode) {
  SqlError.SQLITE_FULL || SqlError.SQLITE_NOMEM => VaultFailureCode.storageFull,
  SqlError.SQLITE_CORRUPT ||
  SqlError.SQLITE_NOTADB ||
  SqlError.SQLITE_IOERR => VaultFailureCode.integrityFailure,
  SqlError.SQLITE_READONLY || SqlError.SQLITE_PERM => VaultFailureCode.readOnly,
  SqlError.SQLITE_TOOBIG => VaultFailureCode.payloadTooLarge,
  SqlError.SQLITE_CONSTRAINT when constraintAsConflict =>
    VaultFailureCode.revisionConflict,
  _ => VaultFailureCode.internalFailure,
});

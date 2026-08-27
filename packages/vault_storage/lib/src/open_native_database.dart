// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:drift/native.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'database.dart';

Future<LocalholdVaultDatabase> openNativeVaultDatabase({
  required File databaseFile,
  required Directory privateTemporaryDirectory,
  required BackupExclusionGateway backupExclusion,
}) async {
  final databaseDirectory = databaseFile.parent;
  if (!databaseDirectory.existsSync()) {
    databaseDirectory.createSync(recursive: true);
  }
  if (!privateTemporaryDirectory.existsSync()) {
    privateTemporaryDirectory.createSync(recursive: true);
  }
  await backupExclusion.excludeAbsolutePath(databaseDirectory.absolute.path);
  if (privateTemporaryDirectory.absolute.path !=
      databaseDirectory.absolute.path) {
    await backupExclusion.excludeAbsolutePath(
      privateTemporaryDirectory.absolute.path,
    );
  }
  sqlite.sqlite3.tempDirectory = privateTemporaryDirectory.path;
  return LocalholdVaultDatabase(
    NativeDatabase.createInBackground(
      databaseFile,
      setup: (database) {
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA synchronous = FULL');
        database.execute('PRAGMA wal_autocheckpoint = 256');
        database.execute('PRAGMA secure_delete = ON');
      },
    ),
  );
}

Future<LocalholdVaultDatabase> openNativeVaultDatabaseReadOnly({
  required File databaseFile,
}) async {
  if (!databaseFile.existsSync()) {
    throw const VaultFailure(VaultFailureCode.objectNotFound);
  }
  try {
    final opened = sqlite.sqlite3.open(
      databaseFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    return LocalholdVaultDatabase(
      NativeDatabase.opened(opened, enableMigrations: false),
      isReadOnly: true,
    );
  } on sqlite.SqliteException {
    throw const VaultFailure(VaultFailureCode.integrityFailure);
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('v1 migration creates neutral deterministic unlock entries', () async {
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE vault_envelopes (
        vault_id TEXT NOT NULL PRIMARY KEY,
        master_envelope BLOB NOT NULL,
        recovery_envelope BLOB NULL
      );
      CREATE TABLE vault_selections (
        id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
        vault_id TEXT NOT NULL
      );
      PRAGMA user_version = 1;
    ''');
    final second = VaultId.generate();
    final first = VaultId.generate();
    for (final id in [second, first]) {
      raw.execute(
        'INSERT INTO vault_envelopes '
        '(vault_id, master_envelope, recovery_envelope) VALUES (?, ?, NULL)',
        [
          id.value,
          Uint8List.fromList([1]),
        ],
      );
    }

    final database = LocalholdVaultDatabase(NativeDatabase.opened(raw));
    addTearDown(database.close);
    final entries = await DriftVaultUnlockDirectoryStore(database).list();

    final expected = [first, second]
      ..sort((a, b) => a.value.compareTo(b.value));
    expect(entries.map((entry) => entry.vaultId), expected);
    expect(entries.map((entry) => entry.ordinal), [1, 2]);
    expect(entries.every((entry) => entry.publicLabel == null), isTrue);
  });
}

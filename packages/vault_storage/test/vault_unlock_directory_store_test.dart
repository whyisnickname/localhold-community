// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:test/test.dart';

void main() {
  late LocalholdVaultDatabase database;
  late DriftVaultUnlockDirectoryStore store;

  setUp(() {
    database = LocalholdVaultDatabase(NativeDatabase.memory());
    store = DriftVaultUnlockDirectoryStore(database);
  });

  tearDown(() => database.close());

  test(
    'register preserves stable order and defaults to neutral labels',
    () async {
      final first = VaultId.generate();
      final second = VaultId.generate();

      expect((await store.register(first)).ordinal, 1);
      expect((await store.register(second, publicLabel: 'Travel')).ordinal, 2);
      expect((await store.register(first)).ordinal, 1);

      final entries = await store.list();
      expect(entries.map((entry) => entry.vaultId), [first, second]);
      expect(entries.first.publicLabel, isNull);
      expect(entries.last.publicLabel, 'Travel');
    },
  );

  test('public label can be explicitly set and removed', () async {
    final id = VaultId.generate();
    await store.register(id);

    await store.updatePublicLabel(id, 'Personal');
    expect((await store.list()).single.publicLabel, 'Personal');

    await store.updatePublicLabel(id, null);
    expect((await store.list()).single.publicLabel, isNull);
  });

  test('invalid or missing updates fail closed', () async {
    await expectLater(
      store.updatePublicLabel(VaultId.generate(), 'Label'),
      throwsA(_failure(VaultFailureCode.objectNotFound)),
    );
    await expectLater(
      store.register(VaultId.generate(), publicLabel: ' '),
      throwsA(_failure(VaultFailureCode.invalidInput)),
    );
  });

  test('remove deletes only the selected directory entry', () async {
    final first = VaultId.generate();
    final second = VaultId.generate();
    await store.register(first);
    await store.register(second);

    await store.remove(first);

    expect((await store.list()).map((entry) => entry.vaultId), [second]);
  });
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((failure) => failure.code, 'code', code);

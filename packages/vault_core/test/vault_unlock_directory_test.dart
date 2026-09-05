// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test('neutral entry contains no display metadata beyond ordinal', () {
    final entry = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 2);

    expect(entry.ordinal, 2);
    expect(entry.publicLabel, isNull);
  });

  test('public lock-screen label has a strict bounded contract', () {
    final id = VaultId.generate();

    expect(
      () => VaultUnlockEntry(vaultId: id, ordinal: 0),
      throwsA(_failure(VaultFailureCode.invalidInput)),
    );
    expect(
      () => VaultUnlockEntry(vaultId: id, ordinal: 1, publicLabel: '   '),
      throwsA(_failure(VaultFailureCode.invalidInput)),
    );
    expect(
      () => VaultUnlockEntry(vaultId: id, ordinal: 1, publicLabel: 'x' * 81),
      throwsA(_failure(VaultFailureCode.invalidInput)),
    );
  });
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((failure) => failure.code, 'code', code);

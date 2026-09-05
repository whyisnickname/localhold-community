// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  const parser = TotpIntakeParser();

  test('TOTP URI produces a reviewable preview before vault value', () {
    final preview = parser.parseUri(
      'otpauth://totp/Example:alice%40example.com?'
      'secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256&digits=8&period=60',
    );
    addTearDown(preview.dispose);
    expect(preview.issuer, 'Example');
    expect(preview.account, 'alice@example.com');
    expect(preview.algorithm, TotpAlgorithm.sha256);
    expect(preview.digits, 8);
    expect(preview.periodSeconds, 60);
    expect(preview.toVaultValue()['secretBase32'], 'JBSWY3DPEHPK3PXP');
    final credential = preview.createCredential();
    addTearDown(credential.dispose);
    expect(credential.secret, isNotEmpty);
  });

  test('manual Base32 accepts readable separators and canonicalizes', () {
    final preview = parser.parseManual(
      secret: 'jbsw y3dp-ehpk3pxp',
      issuer: 'Example',
      account: 'alice',
    );
    addTearDown(preview.dispose);
    expect(preview.toVaultValue()['secretBase32'], 'JBSWY3DPEHPK3PXP');
  });

  test('ordinary URL, HOTP and deceptive issuer mismatch fail closed', () {
    for (final value in [
      'https://example.test/?secret=JBSWY3DPEHPK3PXP',
      'otpauth://hotp/Example:alice?secret=JBSWY3DPEHPK3PXP&counter=1',
      'otpauth://totp/First:alice?secret=JBSWY3DPEHPK3PXP&issuer=Second',
      'otpauth://totp/Example:alice?secret=not_base32!',
    ]) {
      expect(() => parser.parseUri(value), throwsA(isA<VaultFailure>()));
    }
  });

  test('oversized QR payload is rejected before URI processing', () {
    final value = 'otpauth://totp/a?secret=${'A' * 9000}';
    expect(
      () => parser.parseUri(value),
      throwsA(
        isA<VaultFailure>().having(
          (error) => error.code,
          'code',
          VaultFailureCode.payloadTooLarge,
        ),
      ),
    );
  });
}

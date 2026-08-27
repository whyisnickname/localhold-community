// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test('password generator satisfies every selected class', () {
    final value = SecurePasswordGenerator(random: Random(42))
        .generate(const PasswordGeneratorOptions(length: 64));
    expect(value, hasLength(64));
    expect(value, matches(RegExp('[a-z]')));
    expect(value, matches(RegExp('[A-Z]')));
    expect(value, matches(RegExp('[0-9]')));
    expect(value, matches(RegExp(r'[!@#\$%^&*()_+\-=\[\]{}:,.?]')));
  });

  test('impossible generator policy fails closed', () {
    expect(
      () => SecurePasswordGenerator(random: Random(1)).generate(
        const PasswordGeneratorOptions(
          lowercase: true,
          uppercase: false,
          digits: false,
          symbols: false,
          excludedCharacters: 'abcdefghijklmnopqrstuvwxyz',
        ),
      ),
      throwsA(isA<VaultFailure>()),
    );
  });

  test('RFC 6238 SHA-1, SHA-256 and SHA-512 vectors', () {
    const expected = <TotpAlgorithm, String>{
      TotpAlgorithm.sha1: '94287082',
      TotpAlgorithm.sha256: '46119246',
      TotpAlgorithm.sha512: '90693936',
    };
    const secrets = <TotpAlgorithm, String>{
      TotpAlgorithm.sha1: '12345678901234567890',
      TotpAlgorithm.sha256: '12345678901234567890123456789012',
      TotpAlgorithm.sha512:
          '1234567890123456789012345678901234567890123456789012345678901234',
    };
    for (final algorithm in TotpAlgorithm.values) {
      final credential = TotpCredential(
        secret: Uint8List.fromList(ascii.encode(secrets[algorithm]!)),
        algorithm: algorithm,
        digits: 8,
      );
      expect(
        const TotpGenerator().generate(
          credential,
          DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
        ),
        expected[algorithm],
      );
      credential.dispose();
      expect(credential.secret, everyElement(0));
    }
  });
}

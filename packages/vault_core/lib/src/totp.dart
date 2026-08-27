// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'errors.dart';

enum TotpAlgorithm { sha1, sha256, sha512 }

final class TotpCredential {
  TotpCredential({
    required Uint8List secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.periodSeconds = 30,
  }) : secret = Uint8List.fromList(secret) {
    if (secret.isEmpty ||
        secret.length > 1024 ||
        (digits != 6 && digits != 8) ||
        (periodSeconds != 30 && periodSeconds != 60)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final Uint8List secret;
  final TotpAlgorithm algorithm;
  final int digits;
  final int periodSeconds;

  void dispose() => secret.fillRange(0, secret.length, 0);
}

final class TotpGenerator {
  const TotpGenerator();

  String generate(TotpCredential credential, DateTime time) {
    final seconds = time.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (seconds < 0) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final counter = seconds ~/ credential.periodSeconds;
    final message = ByteData(8)..setUint64(0, counter);
    final hmac = Hmac(_hashFor(credential.algorithm), credential.secret);
    final digest = hmac.convert(message.buffer.asUint8List()).bytes;
    final offset = digest.last & 0x0f;
    final binary =
        ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final modulus = credential.digits == 6 ? 1000000 : 100000000;
    return (binary % modulus).toString().padLeft(credential.digits, '0');
  }

  Hash _hashFor(TotpAlgorithm algorithm) => switch (algorithm) {
    TotpAlgorithm.sha1 => sha1,
    TotpAlgorithm.sha256 => sha256,
    TotpAlgorithm.sha512 => sha512,
  };
}

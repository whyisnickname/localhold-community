// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'errors.dart';
import 'totp.dart';

final class TotpImportPreview {
  TotpImportPreview._({
    required Uint8List secret,
    required this.issuer,
    required this.account,
    required this.algorithm,
    required this.digits,
    required this.periodSeconds,
  }) : _secret = Uint8List.fromList(secret);

  final Uint8List _secret;
  final String issuer;
  final String account;
  final TotpAlgorithm algorithm;
  final int digits;
  final int periodSeconds;

  TotpCredential createCredential() => TotpCredential(
    secret: Uint8List.fromList(_secret),
    algorithm: algorithm,
    digits: digits,
    periodSeconds: periodSeconds,
  );

  Map<String, Object?> toVaultValue() => {
    'schemaVersion': 1,
    'secretBase32': _encodeBase32(_secret),
    'issuer': issuer,
    'account': account,
    'algorithm': algorithm.name,
    'digits': digits,
    'periodSeconds': periodSeconds,
  };

  void dispose() => _secret.fillRange(0, _secret.length, 0);

  static String _encodeBase32(Uint8List bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final output = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        output.write(alphabet[(buffer >> bits) & 31]);
        buffer &= (1 << bits) - 1;
      }
    }
    if (bits > 0) output.write(alphabet[(buffer << (5 - bits)) & 31]);
    return output.toString();
  }
}

final class TotpIntakeParser {
  const TotpIntakeParser();

  static const maximumPayloadBytes = 8192;

  TotpImportPreview parseUri(String payload) {
    if (utf8.encode(payload).length > maximumPayloadBytes) {
      throw const VaultFailure(VaultFailureCode.payloadTooLarge);
    }
    final Uri uri;
    try {
      uri = Uri.parse(payload.trim());
    } on FormatException {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    if (uri.scheme.toLowerCase() != 'otpauth' ||
        uri.host.toLowerCase() != 'totp' ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.pathSegments.isEmpty) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }

    final label = uri.pathSegments.join('/').trim();
    if (label.isEmpty || label.length > 512) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final separator = label.indexOf(':');
    final labelIssuer = separator < 0
        ? ''
        : label.substring(0, separator).trim();
    final account = (separator < 0 ? label : label.substring(separator + 1))
        .trim();
    final queryIssuer = (uri.queryParameters['issuer'] ?? '').trim();
    if (account.isEmpty ||
        account.length > 256 ||
        labelIssuer.length > 256 ||
        queryIssuer.length > 256 ||
        (labelIssuer.isNotEmpty &&
            queryIssuer.isNotEmpty &&
            labelIssuer != queryIssuer)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final secret = uri.queryParameters['secret'];
    if (secret == null) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    return _build(
      secret: secret,
      issuer: queryIssuer.isNotEmpty ? queryIssuer : labelIssuer,
      account: account,
      algorithm: _algorithm(uri.queryParameters['algorithm']),
      digits: _number(uri.queryParameters['digits'], defaultValue: 6),
      periodSeconds: _number(uri.queryParameters['period'], defaultValue: 30),
    );
  }

  TotpImportPreview parseManual({
    required String secret,
    required String account,
    String issuer = '',
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
    int digits = 6,
    int periodSeconds = 30,
  }) => _build(
    secret: secret,
    issuer: issuer.trim(),
    account: account.trim(),
    algorithm: algorithm,
    digits: digits,
    periodSeconds: periodSeconds,
  );

  TotpImportPreview _build({
    required String secret,
    required String issuer,
    required String account,
    required TotpAlgorithm algorithm,
    required int digits,
    required int periodSeconds,
  }) {
    if (account.isEmpty ||
        account.length > 256 ||
        issuer.length > 256 ||
        (digits != 6 && digits != 8) ||
        (periodSeconds != 30 && periodSeconds != 60)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final decoded = _decodeBase32(secret);
    if (decoded.isEmpty || decoded.length > 1024) {
      decoded.fillRange(0, decoded.length, 0);
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    try {
      return TotpImportPreview._(
        secret: decoded,
        issuer: issuer,
        account: account,
        algorithm: algorithm,
        digits: digits,
        periodSeconds: periodSeconds,
      );
    } finally {
      decoded.fillRange(0, decoded.length, 0);
    }
  }

  TotpAlgorithm _algorithm(String? value) => switch (value?.toUpperCase()) {
    null || '' || 'SHA1' => TotpAlgorithm.sha1,
    'SHA256' => TotpAlgorithm.sha256,
    'SHA512' => TotpAlgorithm.sha512,
    _ => throw const VaultFailure(VaultFailureCode.invalidInput),
  };

  int _number(String? value, {required int defaultValue}) {
    if (value == null || value.isEmpty) return defaultValue;
    return int.tryParse(value) ??
        (throw const VaultFailure(VaultFailureCode.invalidInput));
  }

  String _canonicalBase32(String value) {
    final normalized = value
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceFirst(RegExp(r'=+$'), '');
    if (normalized.isEmpty || !RegExp(r'^[A-Z2-7]+$').hasMatch(normalized)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    return normalized;
  }

  Uint8List _decodeBase32(String value) {
    final normalized = _canonicalBase32(value);
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var buffer = 0;
    var bits = 0;
    final bytes = <int>[];
    for (final codePoint in normalized.codeUnits) {
      final index = alphabet.indexOf(String.fromCharCode(codePoint));
      if (index < 0) throw const VaultFailure(VaultFailureCode.invalidInput);
      buffer = (buffer << 5) | index;
      bits += 5;
      while (bits >= 8) {
        bits -= 8;
        bytes.add((buffer >> bits) & 0xff);
        buffer &= (1 << bits) - 1;
      }
    }
    if (bits > 0 && buffer != 0) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    return Uint8List.fromList(bytes);
  }
}

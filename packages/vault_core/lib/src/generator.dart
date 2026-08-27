// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'errors.dart';

final class PasswordGeneratorOptions {
  const PasswordGeneratorOptions({
    this.length = 20,
    this.lowercase = true,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
    this.excludedCharacters = '',
  });

  final int length;
  final bool lowercase;
  final bool uppercase;
  final bool digits;
  final bool symbols;
  final String excludedCharacters;
}

final class SecurePasswordGenerator {
  SecurePasswordGenerator({Random? random})
    : _random = random ?? Random.secure();

  static const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _symbols = '!@#\$%^&*()-_=+[]{}:,.?';

  final Random _random;

  String generate(PasswordGeneratorOptions options) {
    if (options.length < 8 || options.length > 128) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final excluded = options.excludedCharacters.runes.toSet();
    String allowed(String source) => String.fromCharCodes(
      source.runes.where((rune) => !excluded.contains(rune)),
    );
    final requiredSets = <String>[
      if (options.lowercase) allowed(_lowercase),
      if (options.uppercase) allowed(_uppercase),
      if (options.digits) allowed(_digits),
      if (options.symbols) allowed(_symbols),
    ];
    if (requiredSets.isEmpty ||
        requiredSets.any((set) => set.isEmpty) ||
        options.length < requiredSets.length) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final alphabet = requiredSets.join();
    final chars = <String>[
      for (final set in requiredSets) set[_random.nextInt(set.length)],
    ];
    while (chars.length < options.length) {
      chars.add(alphabet[_random.nextInt(alphabet.length)]);
    }
    chars.shuffle(_random);
    return chars.join();
  }
}

final class PassphraseGenerator {
  PassphraseGenerator({required List<String> words, Random? random})
    : _words = List.unmodifiable(words),
      _random = random ?? Random.secure() {
    if (_words.length < 1024 ||
        _words.toSet().length != _words.length ||
        _words.any((word) => word.trim().isEmpty)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final List<String> _words;
  final Random _random;

  String generate({int wordCount = 6, String separator = '-'}) {
    if (wordCount < 4 ||
        wordCount > 12 ||
        separator.length > 4 ||
        separator.contains('\u0000')) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    return List.generate(
      wordCount,
      (_) => _words[_random.nextInt(_words.length)],
      growable: false,
    ).join(separator);
  }
}

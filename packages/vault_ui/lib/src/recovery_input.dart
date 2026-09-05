// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

/// Native recovery parsers accept ASCII words separated by one space. This
/// normalizer also makes phrases pasted with line breaks interoperable.
Uint8List encodeRecoveryWords(String value) {
  final normalized = value.trim().split(RegExp(r'\s+')).join(' ');
  return Uint8List.fromList(utf8.encode(normalized));
}

Uint8List encodeRecoveryChallenge(Iterable<String> words) =>
    encodeRecoveryWords(words.join(' '));

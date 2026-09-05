// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:localhold_vault_access/localhold_vault_access.dart';
import 'package:test/test.dart';

void main() {
  test('secret byte helper overwrites the caller-owned buffer', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    wipeBytes(bytes);

    expect(bytes, everyElement(0));
  });
}

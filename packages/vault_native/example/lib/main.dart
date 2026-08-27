// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_vault_native/localhold_key_bridge.dart';

void main() {
  // Referencing the facade ensures the plugin remains linked into this harness.
  LocalholdKeyBridge();
  runApp(const MaterialApp(home: SizedBox.shrink()));
}

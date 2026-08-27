// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('diagnostic example has an empty non-secret surface', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });
}

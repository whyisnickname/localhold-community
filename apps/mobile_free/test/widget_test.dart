// SPDX-License-Identifier: MPL-2.0
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_free/main.dart';

void main() {
  testWidgets('Free foundation states the offline boundary', (tester) async {
    await tester.pumpWidget(
      const LocalholdFreeApp(identity: BuildIdentity.community()),
    );

    expect(find.text('Your data stays here'), findsOneWidget);
    expect(find.textContaining('no Localhold account'), findsOneWidget);
  });
}

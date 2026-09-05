// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

void main() {
  testWidgets('reduced motion collapses decorative duration', (tester) async {
    Duration? effective;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            effective = LocalholdMotion.effective(
              context,
              LocalholdMotion.standard,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(effective, Duration.zero);
  });

  testWidgets('normal motion keeps requested duration', (tester) async {
    Duration? effective;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            effective = LocalholdMotion.effective(
              context,
              LocalholdMotion.short,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(effective, LocalholdMotion.short);
  });
}

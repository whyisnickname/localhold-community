// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_product_shell/localhold_product_shell.dart';

void main() {
  testWidgets('compact width uses bottom navigation in approved order', (
    tester,
  ) async {
    await _setSurface(tester, const Size(320, 720));
    LocalholdDestination? selected;
    await tester.pumpWidget(
      _testApp(
        textScale: 2,
        shell: LocalholdAdaptiveShell(
          destination: LocalholdDestination.vault,
          onDestinationSelected: (value) => selected = value,
          content: const Text('content'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('localhold-bottom-navigation')),
      findsOneWidget,
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings'));
    expect(selected, LocalholdDestination.settings);
  });

  testWidgets('medium width uses a rail without a secondary pane', (
    tester,
  ) async {
    await _setSurface(tester, const Size(700, 800));
    await tester.pumpWidget(
      _testApp(
        shell: LocalholdAdaptiveShell(
          destination: LocalholdDestination.security,
          onDestinationSelected: (_) {},
          content: const Text('content'),
          secondaryPane: const Text('secondary'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('localhold-navigation-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('localhold-secondary-pane')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded width exposes the optional secondary pane', (
    tester,
  ) async {
    await _setSurface(tester, const Size(1000, 800));
    await tester.pumpWidget(
      _testApp(
        locale: const Locale('ru'),
        shell: LocalholdAdaptiveShell(
          destination: LocalholdDestination.subscriptions,
          onDestinationSelected: (_) {},
          content: const Text('основное'),
          secondaryPane: const Text('дополнительное'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('localhold-navigation-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('localhold-secondary-pane')),
      findsOneWidget,
    );
    expect(find.text('Хранилище'), findsOneWidget);
    expect(find.text('Подписки'), findsOneWidget);
  });
}

Widget _testApp({
  required Widget shell,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: LocalholdLocalizations.supportedLocales,
  localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
  theme: LocalholdTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: shell,
);

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

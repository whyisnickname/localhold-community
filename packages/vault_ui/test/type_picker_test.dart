// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test('controller sanitizes, deduplicates and bounds recent types', () {
    final controller = TypePickerController(
      recentTypeIds: [
        BuiltInRecordTypes.account,
        'unknown',
        BuiltInRecordTypes.account,
        BuiltInRecordTypes.subscription,
        BuiltInRecordTypes.database,
        BuiltInRecordTypes.router,
        BuiltInRecordTypes.server,
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.recentTemplates.map((template) => template.stableId), [
      BuiltInRecordTypes.account,
      BuiltInRecordTypes.subscription,
      BuiltInRecordTypes.database,
      BuiltInRecordTypes.router,
    ]);

    controller.rememberSelection(BuiltInRecordTypes.server);
    expect(controller.recentTemplates.map((template) => template.stableId), [
      BuiltInRecordTypes.server,
      BuiltInRecordTypes.account,
      BuiltInRecordTypes.subscription,
      BuiltInRecordTypes.database,
    ]);
  });

  test('controller searches both fallback and localized names', () {
    final controller = TypePickerController();
    addTearDown(controller.dispose);

    controller.setQuery('банк');
    final localized = controller.templatesIn(
      TemplateCategory.money,
      localizedName: (stableId) => stableId == BuiltInRecordTypes.paymentCard
          ? 'Банковская карта'
          : stableId,
    );
    expect(localized.single.stableId, BuiltInRecordTypes.paymentCard);

    controller.setQuery('subscription');
    final fallback = controller.templatesIn(
      TemplateCategory.money,
      localizedName: (stableId) => stableId,
    );
    expect(fallback.single.stableId, BuiltInRecordTypes.subscription);
  });

  test('every built-in field has a reviewed Russian catalog value', () {
    final strings = lookupLocalholdLocalizations(const Locale('ru'));
    const intentionallyInternational = {'iban', 'bic', 'swift', 'pin', 'ssl'};
    for (final template in BuiltInTemplateCatalog.all) {
      for (final definition in template.fields) {
        final field = VaultField(
          id: FieldId.generate(),
          kind: definition.kind,
          label: definition.defaultLabel,
          value: null,
          definitionId: definition.stableId,
        );
        final localized = localizedTemplateFieldLabel(
          strings,
          template.stableId,
          field,
        );
        expect(localized.trim(), isNotEmpty);
        if (!intentionallyInternational.contains(definition.stableId)) {
          expect(
            localized,
            isNot(definition.defaultLabel),
            reason: '${template.stableId}:${definition.stableId}',
          );
        }
      }
    }
  });

  testWidgets('picker preserves approved category and custom-action order', (
    tester,
  ) async {
    final controller = TypePickerController(
      recentTypeIds: [BuiltInRecordTypes.paymentCard],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        child: TypePickerScreen(
          controller: controller,
          onTypeSelected: (_) {},
          onCustomType: () {},
        ),
      ),
    );

    final recent = tester.getTopLeft(find.text('Recently used')).dy;
    final accounts = tester.getTopLeft(find.text('Accounts')).dy;
    expect(recent, lessThan(accounts));
    await _scrollToCustomAction(tester);
    expect(find.text('Premium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker searches in Russian and returns a stable template', (
    tester,
  ) async {
    final controller = TypePickerController();
    addTearDown(controller.dispose);
    RecordTypeDefinition? selected;
    await tester.pumpWidget(
      _app(
        locale: const Locale('ru'),
        child: TypePickerScreen(
          controller: controller,
          onTypeSelected: (value) => selected = value,
          onCustomType: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'криптовалютный аккаунт');
    await tester.pump();
    expect(find.text('Криптовалютный аккаунт'), findsOneWidget);
    expect(find.text('Аккаунт'), findsNothing);
    await tester.tap(find.text('Криптовалютный аккаунт'));
    expect(selected?.stableId, BuiltInRecordTypes.cryptoAccount);
  });

  testWidgets('picker reflows at 320 px and 200% Russian text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);
    final controller = TypePickerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        locale: const Locale('ru'),
        textScale: 2,
        child: TypePickerScreen(
          controller: controller,
          onTypeSelected: (_) {},
          onCustomType: () {},
        ),
      ),
    );

    expect(find.text('Выберите тип записи'), findsOneWidget);
    await _scrollToCustomAction(tester);
    expect(find.text('Premium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required Widget child,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: LocalholdLocalizations.supportedLocales,
  localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
  theme: LocalholdTheme.light(),
  builder: (context, value) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: value!,
  ),
  home: child,
);

Future<void> _scrollToCustomAction(WidgetTester tester) async {
  final target = find.byKey(const ValueKey('type_picker_custom'));
  for (var attempt = 0; attempt < 20; attempt++) {
    if (target.evaluate().isNotEmpty &&
        tester
            .getRect(target.first)
            .overlaps(tester.getRect(find.byType(CustomScrollView)))) {
      return;
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();
  }
  fail('Custom type action did not become visible');
}

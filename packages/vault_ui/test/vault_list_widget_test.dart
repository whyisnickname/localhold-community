// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  testWidgets('Russian compact list reflows at 320 px and 200% text', (
    tester,
  ) async {
    await _surface(tester);
    final port = _WidgetListPort([_record('Почта', 'WIDGET_SECRET_CANARY')]);
    final controller = VaultListController(
      data: port,
      preferences: MemoryVaultListPreferencesPort(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _app(
        locale: const Locale('ru'),
        textScale: 2,
        child: VaultListScreen(
          controller: controller,
          onOpenRecord: (_) {},
          onBulkIntent: (_) {},
        ),
      ),
    );

    expect(find.text('Все записи'), findsOneWidget);
    expect(find.text('Почта'), findsOneWidget);
    expect(find.textContaining('WIDGET_SECRET_CANARY'), findsNothing);
    expect(tester.takeException(), isNull);

    await controller.setLayout(VaultListLayout.grid);
    await tester.pump();
    expect(find.text('Почта'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('protected search explains reauth and keeps result masked', (
    tester,
  ) async {
    const secret = 'PROTECTED_WIDGET_CANARY';
    final port = _WidgetListPort([_record('Work', secret)])
      ..reauthenticationResult = true;
    final controller = VaultListController(
      data: port,
      preferences: MemoryVaultListPreferencesPort(),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _app(
        child: VaultListScreen(
          controller: controller,
          onOpenRecord: (_) {},
          onBulkIntent: (_) {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Search protected fields'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Results stay masked'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), secret);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Protected search is on'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text(secret)),
      findsNothing,
    );
  });

  testWidgets(
    'bulk surface omits reveal, copy, conversion and permanent delete',
    (tester) async {
      final port = _WidgetListPort([_record('One', '')]);
      final controller = VaultListController(
        data: port,
        preferences: MemoryVaultListPreferencesPort(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        _app(
          child: VaultListScreen(
            controller: controller,
            onOpenRecord: (_) {},
            onBulkIntent: (_) {},
          ),
        ),
      );

      await tester.longPress(find.text('One'));
      await tester.pump();
      expect(find.text('Export selected'), findsOneWidget);
      expect(find.text('Delete permanently'), findsNothing);
      expect(find.text('Reveal'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Apply conversion'), findsNothing);
    },
  );

  testWidgets('Trash explains retention and offers per-record restore', (
    tester,
  ) async {
    final record = _record(
      'Removed',
      '',
    ).copyWith(lifecycle: RecordLifecycle.trashed);
    final controller = VaultListController(
      data: _WidgetListPort([record]),
      preferences: MemoryVaultListPreferencesPort(),
    );
    addTearDown(controller.dispose);
    await controller.load();
    controller.setFilter(
      const VaultSearchFilter(lifecycle: RecordLifecycle.trashed),
    );
    await tester.pumpWidget(
      _app(
        child: VaultListScreen(
          controller: controller,
          onOpenRecord: (_) {},
          onBulkIntent: (_) {},
        ),
      ),
    );

    expect(find.textContaining('30 days'), findsOneWidget);
    expect(find.byTooltip('Restore'), findsOneWidget);
    expect(find.text('Delete permanently'), findsNothing);
  });
}

final class _WidgetListPort implements VaultListDataPort {
  _WidgetListPort(this.records);

  List<VaultRecord> records;
  bool reauthenticationResult = false;

  @override
  Future<VaultListLoadData> load() async => VaultListLoadData(
    records: records,
    organization: VaultOrganization.empty(),
  );

  @override
  Future<List<VaultRecord>> applyBulk({
    required List<VaultRecord> records,
    required BulkRecordCommand command,
    required VaultOrganization organization,
    required DateTime now,
  }) async => applyBulkRecordCommand(
    records,
    command,
    now: now,
    organization: organization,
  );

  @override
  Future<bool> reauthenticateProtectedSearch() async => reauthenticationResult;

  @override
  Future<void> requestPortabilityExport(Set<RecordId> recordIds) async {}

  @override
  Future<VaultRecord> savePinned({
    required VaultRecord record,
    required bool pinned,
    required DateTime now,
  }) async => record.copyWith(pinned: pinned, updatedAt: now);

  @override
  Future<VaultRecord> restore({
    required VaultRecord record,
    required DateTime now,
  }) async => restoreRecord(record, now);
}

VaultRecord _record(String title, String secret) {
  final now = DateTime.utc(2026, 9, 5);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: BuiltInRecordTypes.account,
    fields: [
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.text,
        label: 'Title',
        value: title,
        definitionId: 'title',
      ),
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.secret,
        label: 'Password',
        value: secret,
        definitionId: 'password',
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
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

Future<void> _surface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  addTearDown(tester.view.reset);
}

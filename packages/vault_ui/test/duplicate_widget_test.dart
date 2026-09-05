// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  testWidgets('candidate screen is safe and reflows in Russian at 320/200%', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);
    final port = _WidgetPort([
      _record('Почта', 'owner', 'secret-canary'),
      _record('ПОЧТА', 'OWNER', 'other-canary'),
    ]);
    final controller = LocalDuplicateController(data: port);
    addTearDown(controller.dispose);
    await controller.scan();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: LocalholdLocalizations.supportedLocales,
        localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
        theme: LocalholdTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: LocalDuplicateScreen(controller: controller),
      ),
    );

    expect(find.text('Возможные дубли'), findsOneWidget);
    expect(find.textContaining('secret-canary'), findsNothing);
    expect(find.textContaining('other-canary'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merge comparison masks secrets and requires field choices', (
    tester,
  ) async {
    final first = _record('Account', 'old-user', 'first-secret');
    final second = _record('Account', 'new-user', 'second-secret');
    final port = _WidgetPort([first, second]);
    final controller = LocalDuplicateController(data: port);
    addTearDown(controller.dispose);
    await controller.scan();
    controller.prepareMerge(first.id, second.id, targetId: first.id);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: LocalholdLocalizations.supportedLocales,
        localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
        theme: LocalholdTheme.light(),
        home: LocalDuplicateScreen(controller: controller),
      ),
    );

    expect(find.textContaining('first-secret'), findsNothing);
    expect(find.textContaining('second-secret'), findsNothing);
    final masked = find.textContaining(LocalMergeFieldView.mask);
    for (
      var attempt = 0;
      attempt < 10 && masked.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
      await tester.pump();
    }
    expect(masked, findsNWidgets(2));
    expect(controller.canCommitMerge, isFalse);
  });
}

final class _WidgetPort implements LocalDuplicateDataPort {
  _WidgetPort(this.records);

  List<VaultRecord> records;

  @override
  Future<LocalDuplicateLoadData> load() async => LocalDuplicateLoadData(
    records: records,
    organization: VaultOrganization.empty(),
  );

  @override
  Future<RecordMergeResult> merge({
    required RecordMergeCommand command,
    required DateTime now,
  }) => throw UnimplementedError();

  @override
  Future<bool> reauthenticateProtectedComparison() async => true;
}

VaultRecord _record(String title, String username, String password) {
  final now = DateTime.utc(2026, 9, 5);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: BuiltInRecordTypes.account,
    fields: [
      _field('title', VaultFieldKind.text, title),
      _field('username', VaultFieldKind.username, username),
      _field('password', VaultFieldKind.secret, password),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

VaultField _field(String id, VaultFieldKind kind, String value) => VaultField(
  id: FieldId.generate(),
  kind: kind,
  label: id,
  value: value,
  definitionId: id,
);

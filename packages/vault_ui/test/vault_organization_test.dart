// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test(
    'organization controller persists folders and non-destructive tag deletion',
    () async {
      final tagged = _taggedRecord();
      final port = _OrganizationPort(records: [tagged.$1]);
      final controller = VaultOrganizationController(data: port);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.addFolder('Work');
      await controller.addTag('Old');
      final addedTag = controller.state.tags.single;
      port.records = [
        tagged.$1.copyWith(tagIds: [addedTag.id]),
      ];
      await controller.load();
      await controller.deleteTag(addedTag.id, now: DateTime.utc(2026, 9, 5));

      expect(controller.state.folders.single.name, 'Work');
      expect(controller.state.tags, isEmpty);
      expect(port.records.single.id, tagged.$1.id);
      expect(port.records.single.tagIds, isEmpty);
    },
  );

  testWidgets('organization manager reflows in Russian at 320 px and 200%', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);
    final port = _OrganizationPort(records: const []);
    final controller = VaultOrganizationController(data: port);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.addFolder('Работа');
    await controller.addTag('Важное');

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
        home: VaultOrganizationScreen(
          controller: controller,
          onMoveFolder: (_) {},
          onMergeTag: (_) {},
        ),
      ),
    );

    expect(find.text('Папки и теги'), findsOneWidget);
    expect(find.text('Работа'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Важное'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Важное'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _OrganizationPort implements VaultOrganizationDataPort {
  _OrganizationPort({required this.records});

  List<VaultRecord> records;
  VaultOrganization? organization;

  @override
  Future<VaultOrganizationLoadData> load() async => VaultOrganizationLoadData(
    organization: organization ?? VaultOrganization.empty(),
    records: records,
    persisted: organization != null,
  );

  @override
  Future<VaultOrganization> saveOrganization({
    required VaultOrganization organization,
    required bool persisted,
  }) async {
    this.organization = persisted
        ? organization.copyWith(revision: organization.revision + 1)
        : organization;
    return this.organization!;
  }

  @override
  Future<EncryptedOrganizationMutationResult> saveOrganizationWithRecords({
    required VaultOrganization organization,
    required List<VaultRecord> records,
    required DateTime now,
  }) async {
    final savedRecords = records
        .map((record) => record.copyWith(revision: record.revision + 1))
        .toList();
    final byId = {for (final record in savedRecords) record.id: record};
    this.records = this.records
        .map((record) => byId[record.id] ?? record)
        .toList();
    this.organization = organization.copyWith(
      revision: organization.revision + 1,
    );
    return EncryptedOrganizationMutationResult(
      organization: this.organization!,
      records: savedRecords,
    );
  }
}

(VaultRecord, VaultTag) _taggedRecord() {
  final tag = VaultTag(id: TagId.generate(), name: 'Old');
  final now = DateTime.utc(2026, 9, 5);
  return (
    VaultRecord(
      id: RecordId.generate(),
      typeId: BuiltInRecordTypes.account,
      fields: [
        VaultField(
          id: FieldId.generate(),
          kind: VaultFieldKind.text,
          label: 'Title',
          value: 'One',
          definitionId: 'title',
        ),
      ],
      createdAt: now,
      updatedAt: now,
      tagIds: [tag.id],
    ),
    tag,
  );
}

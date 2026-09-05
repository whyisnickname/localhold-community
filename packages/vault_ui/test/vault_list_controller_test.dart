// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test(
    'list state exposes safe projections and protected search needs reauth',
    () async {
      const secret = 'D06_CONTROLLER_SECRET';
      final record = _record(title: 'Mail', password: secret);
      final port = _ListPort([record]);
      final controller = VaultListController(
        data: port,
        preferences: MemoryVaultListPreferencesPort(),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.state.status, VaultListStatus.ready);
      expect(controller.state.items.single.toString(), isNot(contains(secret)));

      controller.setQuery(secret);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(controller.state.status, VaultListStatus.empty);

      expect(await controller.enableProtectedSearch(), isFalse);
      expect(controller.state.issue, VaultListIssue.authorizationDenied);
      port.reauthenticationResult = true;
      expect(await controller.enableProtectedSearch(), isTrue);
      expect(controller.state.items.single.displayName, 'Mail');
      expect(controller.state.items.single.toString(), isNot(contains(secret)));
    },
  );

  test(
    'background clears query, results, selection and authorization',
    () async {
      final port = _ListPort([_record(title: 'One')])
        ..reauthenticationResult = true;
      final controller = VaultListController(
        data: port,
        preferences: MemoryVaultListPreferencesPort(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.enableProtectedSearch();
      controller.setQuery('One');
      controller.toggleSelection(controller.state.items.single.id);

      controller.onBackgroundOrLock();

      expect(controller.state.status, VaultListStatus.locked);
      expect(controller.state.query, isEmpty);
      expect(controller.state.items, isEmpty);
      expect(controller.state.selectedIds, isEmpty);
      expect(controller.state.protectedSearch, isFalse);
    },
  );

  test(
    'layout and sort persist while filter and selection stay transient',
    () async {
      final preferences = MemoryVaultListPreferencesPort();
      final port = _ListPort([_record(title: 'Zulu'), _record(title: 'Alpha')]);
      final controller = VaultListController(
        data: port,
        preferences: preferences,
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.setLayout(VaultListLayout.grid);
      await controller.setSort(VaultRecordSort.safeTitleAscending);
      controller.setFilter(
        const VaultSearchFilter(
          lifecycle: RecordLifecycle.active,
          favoriteOnly: true,
        ),
      );

      expect((await preferences.read()).layout, VaultListLayout.grid);
      expect(
        (await preferences.read()).sort,
        VaultRecordSort.safeTitleAscending,
      );
      expect(controller.state.items, isEmpty);
    },
  );

  test(
    'reauth completion after background cannot restore protected state',
    () async {
      final port = _ListPort([_record(title: 'One')]);
      final pending = Completer<bool>();
      port.pendingReauthentication = pending;
      final controller = VaultListController(
        data: port,
        preferences: MemoryVaultListPreferencesPort(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final authorization = controller.enableProtectedSearch();
      controller.onBackgroundOrLock();
      pending.complete(true);

      expect(await authorization, isFalse);
      expect(controller.state.status, VaultListStatus.locked);
      expect(controller.state.protectedSearch, isFalse);
    },
  );

  test('folder and tag filters combine without persistence', () async {
    final folder = VaultFolder(id: FolderId.generate(), name: 'Work');
    final tag = VaultTag(id: TagId.generate(), name: 'Important');
    final organization = VaultOrganization(
      id: OrganizationId.generate(),
      folders: [folder],
      tags: [tag],
    );
    final matching = _record(title: 'Matching')
        .copyWith(folderId: folder.id, tagIds: [tag.id]);
    final port = _ListPort([
      matching,
      _record(title: 'Other'),
    ], organization: organization);
    final controller = VaultListController(
      data: port,
      preferences: MemoryVaultListPreferencesPort(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.setFolderFilter(folder.id);
    controller.toggleTagFilter(tag.id);

    expect(controller.state.items.single.displayName, 'Matching');
    expect(controller.state.filter.folderId, folder.id.value);
    expect(controller.state.filter.requiredTagIds, {tag.id.value});
  });

  test('bulk mutation and export use only selected record IDs', () async {
    final port = _ListPort([_record(title: 'One'), _record(title: 'Two')]);
    final controller = VaultListController(
      data: port,
      preferences: MemoryVaultListPreferencesPort(),
    );
    addTearDown(controller.dispose);
    await controller.load();
    final selected = controller.state.items.first.id;
    controller.toggleSelection(selected);
    await controller.requestPortabilityExport();
    expect(port.exported, {selected});

    await controller.applyBulk(
      const BulkRecordCommand.setFavorite(true),
      now: DateTime.utc(2026, 9, 5),
    );
    expect(
      port.records.singleWhere((value) => value.id == selected).favorite,
      isTrue,
    );
    expect(controller.state.selectedIds, isEmpty);
  });
}

final class _ListPort implements VaultListDataPort {
  _ListPort(Iterable<VaultRecord> records, {VaultOrganization? organization})
    : records = List<VaultRecord>.of(records),
      organization = organization ?? VaultOrganization.empty();

  List<VaultRecord> records;
  bool reauthenticationResult = false;
  Completer<bool>? pendingReauthentication;
  Set<RecordId> exported = const {};
  final VaultOrganization organization;

  @override
  Future<VaultListLoadData> load() async =>
      VaultListLoadData(records: records, organization: organization);

  @override
  Future<List<VaultRecord>> applyBulk({
    required List<VaultRecord> records,
    required BulkRecordCommand command,
    required VaultOrganization organization,
    required DateTime now,
  }) async {
    final saved = applyBulkRecordCommand(
      records,
      command,
      now: now,
      organization: organization,
    ).map((record) => record.copyWith(revision: record.revision + 1)).toList();
    final byId = {for (final record in saved) record.id: record};
    this.records = this.records
        .map((record) => byId[record.id] ?? record)
        .toList();
    return saved;
  }

  @override
  Future<bool> reauthenticateProtectedSearch() async =>
      pendingReauthentication == null
      ? reauthenticationResult
      : pendingReauthentication!.future;

  @override
  Future<void> requestPortabilityExport(Set<RecordId> recordIds) async {
    exported = Set.unmodifiable(recordIds);
  }

  @override
  Future<VaultRecord> savePinned({
    required VaultRecord record,
    required bool pinned,
    required DateTime now,
  }) async {
    final saved = record.copyWith(
      pinned: pinned,
      revision: record.revision + 1,
      updatedAt: now,
    );
    records = records
        .map((value) => value.id == saved.id ? saved : value)
        .toList();
    return saved;
  }

  @override
  Future<VaultRecord> restore({
    required VaultRecord record,
    required DateTime now,
  }) async {
    final saved = restoreRecord(
      record,
      now,
    ).copyWith(revision: record.revision + 1);
    records = records
        .map((value) => value.id == saved.id ? saved : value)
        .toList();
    return saved;
  }
}

VaultRecord _record({required String title, String password = ''}) {
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
        value: password,
        definitionId: 'password',
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

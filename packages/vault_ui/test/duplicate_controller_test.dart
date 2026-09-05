// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test('manual scan exposes safe candidate projections only', () async {
    final port = _DuplicatePort(
      records: [
        _record('Email', 'owner', 'secret-canary'),
        _record('ÉMAIL', 'OWNER', 'different-secret'),
      ],
    );
    final controller = LocalDuplicateController(data: port);
    addTearDown(controller.dispose);

    await controller.scan();

    expect(controller.state.status, DuplicateStatus.ready);
    expect(controller.state.candidates, hasLength(1));
    final rendered = controller.state.candidates.single.toString();
    expect(rendered, isNot(contains('secret-canary')));
    expect(rendered, isNot(contains('different-secret')));
  });

  test('protected comparison requires reauthentication', () async {
    final port = _DuplicatePort(
      records: [
        _record('First', 'one', 'same-secret'),
        _record('Second', 'two', 'same-secret'),
      ],
      authorized: false,
    );
    final controller = LocalDuplicateController(data: port);
    addTearDown(controller.dispose);

    expect(await controller.scanProtected(), isFalse);
    expect(controller.state.protectedComparison, isFalse);
    port.authorized = true;
    expect(await controller.scanProtected(), isTrue);
    expect(controller.state.protectedComparison, isTrue);
    expect(
      controller.state.candidates.single.reasons,
      contains(DuplicateMatchReason.protectedExactValue),
    );
  });

  test(
    'merge preview masks protected fields and commit uses explicit choices',
    () async {
      final first = _record('First', 'old-user', 'first-secret');
      final second = _record('First', 'new-user', 'second-secret');
      final port = _DuplicatePort(records: [first, second]);
      final controller = LocalDuplicateController(data: port);
      addTearDown(controller.dispose);
      await controller.scan();

      controller.prepareMerge(first.id, second.id, targetId: first.id);
      final merge = controller.state.merge!;
      final secret = merge.fields.firstWhere((field) => field.protected);
      expect(secret.targetValue, LocalMergeFieldView.mask);
      expect(secret.sourceValue, LocalMergeFieldView.mask);
      expect(controller.canCommitMerge, isFalse);
      for (final field in merge.fields) {
        controller.choose(
          field.id,
          field.sourceAvailable
              ? MergeFieldChoice.source
              : MergeFieldChoice.target,
        );
      }
      expect(controller.canCommitMerge, isTrue);

      expect(
        await controller.commitMerge(now: DateTime.utc(2026, 9, 5, 12)),
        isTrue,
      );
      expect(
        port.records.singleWhere((record) => record.id == second.id).lifecycle,
        RecordLifecycle.trashed,
      );
    },
  );

  test('background clears state and suppresses late authorization', () async {
    final completer = Completer<bool>();
    final port = _DuplicatePort(
      records: [_record('One', 'one', 'same'), _record('Two', 'two', 'same')],
      authorization: () => completer.future,
    );
    final controller = LocalDuplicateController(data: port);
    addTearDown(controller.dispose);

    final pending = controller.scanProtected();
    controller.onBackgroundOrLock();
    completer.complete(true);

    expect(await pending, isFalse);
    expect(controller.state.status, DuplicateStatus.locked);
    expect(controller.state.candidates, isEmpty);
    expect(controller.state.merge, isNull);
    expect(controller.state.protectedComparison, isFalse);
  });
}

final class _DuplicatePort implements LocalDuplicateDataPort {
  _DuplicatePort({
    required this.records,
    this.authorized = true,
    this.authorization,
  });

  List<VaultRecord> records;
  bool authorized;
  final Future<bool> Function()? authorization;

  @override
  Future<LocalDuplicateLoadData> load() async => LocalDuplicateLoadData(
    records: records,
    organization: VaultOrganization.empty(),
  );

  @override
  Future<RecordMergeResult> merge({
    required RecordMergeCommand command,
    required DateTime now,
  }) async {
    final target = records.singleWhere(
      (record) => record.id == command.targetId,
    );
    final source = records.singleWhere(
      (record) => record.id == command.sourceId,
    );
    final planner = RecordMergePlanner(definitions: BuiltInTemplateCatalog.all);
    final pair = planner.apply(
      preview: planner.prepare(target: target, source: source),
      choices: command.choices,
      now: now,
    );
    final result = RecordMergeResult(
      target: pair.target.copyWith(revision: target.revision + 1),
      source: pair.source.copyWith(revision: source.revision + 1),
    );
    records = records
        .map(
          (record) => record.id == target.id
              ? result.target
              : record.id == source.id
              ? result.source
              : record,
        )
        .toList();
    return result;
  }

  @override
  Future<bool> reauthenticateProtectedComparison() =>
      authorization?.call() ?? Future.value(authorized);
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

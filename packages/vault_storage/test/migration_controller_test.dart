// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:test/test.dart';

void main() {
  late LocalholdVaultDatabase database;

  setUp(() {
    database = LocalholdVaultDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('verified staging is promoted and journal is cleared', () async {
    final step = _Step();
    final controller = VaultMigrationController(
      database: database,
      steps: [step],
    );
    await controller.migrate(sourceVersion: 1, targetVersion: 2);

    expect(step.events, ['stage', 'verify', 'promote']);
    expect(await database.select(database.migrationJournals).get(), isEmpty);
  });

  test('failed verification rolls back without promotion', () async {
    final step = _Step(failVerification: true);
    final controller = VaultMigrationController(
      database: database,
      steps: [step],
    );
    await expectLater(
      controller.migrate(sourceVersion: 1, targetVersion: 2),
      throwsA(
        isA<VaultFailure>().having(
          (error) => error.code,
          'code',
          VaultFailureCode.migrationFailed,
        ),
      ),
    );

    expect(step.events, ['stage', 'verify', 'rollback']);
    expect(await database.select(database.migrationJournals).get(), isEmpty);
  });

  test('downgrade fails closed before invoking a step', () async {
    final step = _Step();
    final controller = VaultMigrationController(
      database: database,
      steps: [step],
    );
    await expectLater(
      controller.migrate(sourceVersion: 2, targetVersion: 1),
      throwsA(isA<VaultFailure>()),
    );
    expect(step.events, isEmpty);
  });

  for (final phase in [
    VaultMigrationPhase.staged,
    VaultMigrationPhase.failed,
  ]) {
    test('interrupted ${phase.name} state rolls back and can retry', () async {
      final step = _Step();
      await _writeJournal(database, phase, stagingId: _stagingId);
      final controller = VaultMigrationController(
        database: database,
        steps: [step],
      );

      await controller.resumeInterrupted();
      expect(step.events, ['rollback']);
      expect(await database.select(database.migrationJournals).get(), isEmpty);

      step.events.clear();
      await controller.migrate(sourceVersion: 1, targetVersion: 2);
      expect(step.events, ['stage', 'verify', 'promote']);
    });
  }

  for (final phase in [
    VaultMigrationPhase.verified,
    VaultMigrationPhase.promoting,
  ]) {
    test('interrupted ${phase.name} state finishes promotion once', () async {
      final step = _Step();
      await _writeJournal(database, phase, stagingId: _stagingId);
      final controller = VaultMigrationController(
        database: database,
        steps: [step],
      );

      await controller.resumeInterrupted();

      expect(step.events, ['promote']);
      expect(await database.select(database.migrationJournals).get(), isEmpty);
    });
  }

  test('preparing without staging is cleared without touching data', () async {
    final step = _Step();
    await _writeJournal(database, VaultMigrationPhase.preparing);
    final controller = VaultMigrationController(
      database: database,
      steps: [step],
    );

    await controller.resumeInterrupted();

    expect(step.events, isEmpty);
    expect(await database.select(database.migrationJournals).get(), isEmpty);
  });

  test(
    'failed resumed promotion remains journaled for safe rollback',
    () async {
      final step = _Step(failPromotion: true);
      await _writeJournal(
        database,
        VaultMigrationPhase.promoting,
        stagingId: _stagingId,
      );
      final controller = VaultMigrationController(
        database: database,
        steps: [step],
      );

      await expectLater(
        controller.resumeInterrupted(),
        throwsA(_failure(VaultFailureCode.migrationFailed)),
      );
      final journals = await database.select(database.migrationJournals).get();
      // ignore: avoid_print
      print(
        'STAGE4_MIGRATION_JOURNALS '
        '${journals.map((row) => '${row.id}:${row.phase}').join(',')}',
      );
      expect(journals, hasLength(1));
      final journal = journals.single;
      expect(journal.phase, VaultMigrationPhase.failed.name);
      expect(journal.stagingId, _stagingId);
    },
  );
}

final class _Step implements VaultMigrationStep {
  _Step({this.failVerification = false, this.failPromotion = false});

  final bool failVerification;
  final bool failPromotion;
  final List<String> events = [];

  @override
  int get sourceVersion => 1;

  @override
  int get targetVersion => 2;

  @override
  Future<String> stage() async {
    events.add('stage');
    return 'AAAAAAAAAAAAAAAAAAAAAA';
  }

  @override
  Future<void> verify(String stagingId) async {
    events.add('verify');
    if (failVerification) throw StateError('synthetic fault');
  }

  @override
  Future<void> promote(String stagingId) async {
    events.add('promote');
    if (failPromotion) throw StateError('synthetic promotion fault');
  }

  @override
  Future<void> rollback(String stagingId) async {
    events.add('rollback');
  }
}

const _stagingId = 'SSSSSSSSSSSSSSSSSSSSSS';

Future<void> _writeJournal(
  LocalholdVaultDatabase database,
  VaultMigrationPhase phase, {
  String? stagingId,
}) => database.customStatement(
  'INSERT INTO migration_journals '
  '(id, source_version, target_version, phase, staging_id) '
  'VALUES (1, ?, ?, ?, ?)',
  [1, 2, phase.name, stagingId],
);

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

// SPDX-License-Identifier: MPL-2.0

import 'package:drift/drift.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'database.dart';

enum VaultMigrationPhase { preparing, staged, verified, promoting, failed }

abstract interface class VaultMigrationStep {
  int get sourceVersion;
  int get targetVersion;

  /// Writes only authenticated encrypted staging objects.
  Future<String> stage();

  Future<void> verify(String stagingId);

  /// Must atomically promote staging or leave the previous version usable.
  Future<void> promote(String stagingId);

  Future<void> rollback(String stagingId);
}

final class VaultMigrationController {
  const VaultMigrationController({
    required this._database,
    required this._steps,
  });

  final LocalholdVaultDatabase _database;
  final Iterable<VaultMigrationStep> _steps;

  Future<void> migrate({
    required int sourceVersion,
    required int targetVersion,
  }) async {
    if (sourceVersion == targetVersion) return;
    if (sourceVersion > targetVersion) {
      throw const VaultFailure(VaultFailureCode.unsupportedVersion);
    }
    await resumeInterrupted();
    var current = sourceVersion;
    while (current < targetVersion) {
      final candidates = _steps.where((step) => step.sourceVersion == current);
      if (candidates.length != 1) {
        throw const VaultFailure(VaultFailureCode.migrationRequired);
      }
      final step = candidates.single;
      if (step.targetVersion <= current || step.targetVersion > targetVersion) {
        throw const VaultFailure(VaultFailureCode.migrationRequired);
      }
      await _execute(step);
      current = step.targetVersion;
    }
  }

  Future<void> resumeInterrupted() async {
    final journal = await _journal();
    if (journal == null) return;
    final step = _steps.where(
      (candidate) =>
          candidate.sourceVersion == journal.sourceVersion &&
          candidate.targetVersion == journal.targetVersion,
    );
    if (step.length != 1) {
      throw const VaultFailure(VaultFailureCode.migrationFailed);
    }
    final selected = step.single;
    final phase = VaultMigrationPhase.values.where(
      (value) => value.name == journal.phase,
    );
    if (phase.length != 1) {
      throw const VaultFailure(VaultFailureCode.migrationFailed);
    }
    if (phase.single == VaultMigrationPhase.preparing &&
        journal.stagingId == null) {
      await _clearJournal();
      return;
    }
    if (journal.stagingId == null) {
      throw const VaultFailure(VaultFailureCode.migrationFailed);
    }
    try {
      switch (phase.single) {
        case VaultMigrationPhase.preparing:
        case VaultMigrationPhase.staged:
        case VaultMigrationPhase.failed:
          await selected.rollback(journal.stagingId!);
          await _clearJournal();
          return;
        case VaultMigrationPhase.verified:
        case VaultMigrationPhase.promoting:
          await _writeJournal(
            selected,
            VaultMigrationPhase.promoting,
            journal.stagingId,
          );
          await selected.promote(journal.stagingId!);
          await _clearJournal();
          return;
      }
    } on Object {
      await _writeJournal(
        selected,
        VaultMigrationPhase.failed,
        journal.stagingId,
      );
      throw const VaultFailure(VaultFailureCode.migrationFailed);
    }
  }

  Future<void> _execute(VaultMigrationStep step) async {
    String? stagingId;
    try {
      await _writeJournal(step, VaultMigrationPhase.preparing, null);
      stagingId = await step.stage();
      if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(stagingId)) {
        throw const VaultFailure(VaultFailureCode.migrationFailed);
      }
      await _writeJournal(step, VaultMigrationPhase.staged, stagingId);
      await step.verify(stagingId);
      await _writeJournal(step, VaultMigrationPhase.verified, stagingId);
      await _writeJournal(step, VaultMigrationPhase.promoting, stagingId);
      await step.promote(stagingId);
      await _clearJournal();
    } on Object {
      if (stagingId != null) {
        try {
          await step.rollback(stagingId);
          await _clearJournal();
        } on Object {
          await _writeJournal(step, VaultMigrationPhase.failed, stagingId);
        }
      }
      throw const VaultFailure(VaultFailureCode.migrationFailed);
    }
  }

  Future<MigrationJournal?> _journal() => (_database.select(
    _database.migrationJournals,
  )..where((row) => row.id.equals(1))).getSingleOrNull();

  Future<void> _writeJournal(
    VaultMigrationStep step,
    VaultMigrationPhase phase,
    String? stagingId,
  ) => _database
      .into(_database.migrationJournals)
      .insertOnConflictUpdate(
        MigrationJournalsCompanion.insert(
          id: const Value(1),
          sourceVersion: step.sourceVersion,
          targetVersion: step.targetVersion,
          phase: phase.name,
          stagingId: Value(stagingId),
        ),
      );

  Future<void> _clearJournal() =>
      _database.delete(_database.migrationJournals).go();
}

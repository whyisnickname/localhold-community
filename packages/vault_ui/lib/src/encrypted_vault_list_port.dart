// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'vault_list_controller.dart';

final class EncryptedVaultListPort implements VaultListDataPort {
  const EncryptedVaultListPort({
    required this.records,
    required this.organization,
    required this.reauthenticate,
    required this.exportSelection,
  });

  final EncryptedRecordService records;
  final EncryptedOrganizationService organization;
  final Future<bool> Function() reauthenticate;
  final Future<void> Function(Set<RecordId> recordIds) exportSelection;

  @override
  Future<VaultListLoadData> load() async {
    final recordSnapshot = await records.loadAll();
    final organizationSnapshot =
        await organization.loadCurrent() ?? VaultOrganization.empty();
    return VaultListLoadData(
      records: recordSnapshot.records,
      organization: organizationSnapshot,
    );
  }

  @override
  Future<List<VaultRecord>> applyBulk({
    required List<VaultRecord> records,
    required BulkRecordCommand command,
    required VaultOrganization organization,
    required DateTime now,
  }) => this.records.updateMany(
    proposed: applyBulkRecordCommand(
      records,
      command,
      now: now,
      organization: organization,
    ),
    now: now,
  );

  @override
  Future<VaultRecord> savePinned({
    required VaultRecord record,
    required bool pinned,
    required DateTime now,
  }) async {
    final result = await records.update(
      proposed: setPinned(record, pinned, now),
      expectedRevision: record.revision,
      now: now,
    );
    if (result.hasConflict) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    return result.record!;
  }

  @override
  Future<VaultRecord> restore({
    required VaultRecord record,
    required DateTime now,
  }) async {
    final result = await records.update(
      proposed: restoreRecord(record, now),
      expectedRevision: record.revision,
      now: now,
    );
    if (result.hasConflict) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    return result.record!;
  }

  @override
  Future<bool> reauthenticateProtectedSearch() => reauthenticate();

  @override
  Future<void> requestPortabilityExport(Set<RecordId> recordIds) =>
      exportSelection(Set.unmodifiable(recordIds));
}

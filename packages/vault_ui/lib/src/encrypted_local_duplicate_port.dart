// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'local_duplicate_controller.dart';

final class EncryptedLocalDuplicatePort implements LocalDuplicateDataPort {
  const EncryptedLocalDuplicatePort({
    required this.records,
    required this.organization,
    required this.reauthenticate,
  });

  final EncryptedRecordService records;
  final EncryptedOrganizationService organization;
  final Future<bool> Function() reauthenticate;

  @override
  Future<LocalDuplicateLoadData> load() async {
    final recordSnapshot = await records.loadAll();
    final organizationSnapshot =
        await organization.loadCurrent() ?? VaultOrganization.empty();
    return LocalDuplicateLoadData(
      records: recordSnapshot.records,
      organization: organizationSnapshot,
    );
  }

  @override
  Future<RecordMergeResult> merge({
    required RecordMergeCommand command,
    required DateTime now,
  }) => records.merge(command: command, now: now);

  @override
  Future<bool> reauthenticateProtectedComparison() => reauthenticate();
}

// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'vault_organization_controller.dart';

final class EncryptedVaultOrganizationPort
    implements VaultOrganizationDataPort {
  const EncryptedVaultOrganizationPort({
    required this.records,
    required this.organization,
  });

  final EncryptedRecordService records;
  final EncryptedOrganizationService organization;

  @override
  Future<VaultOrganizationLoadData> load() async {
    final recordSnapshot = await records.loadAll();
    final existing = await organization.loadCurrent();
    return VaultOrganizationLoadData(
      organization: existing ?? VaultOrganization.empty(),
      records: recordSnapshot.records,
      persisted: existing != null,
    );
  }

  @override
  Future<VaultOrganization> saveOrganization({
    required VaultOrganization organization,
    required bool persisted,
  }) async {
    if (!persisted) {
      await this.organization.create(organization);
      return organization;
    }
    return this.organization.replace(
      organization,
      expectedRevision: organization.revision,
    );
  }

  @override
  Future<EncryptedOrganizationMutationResult> saveOrganizationWithRecords({
    required VaultOrganization organization,
    required List<VaultRecord> records,
    required DateTime now,
  }) => this.organization.replaceWithRecords(
    organization: organization,
    records: records,
    now: now,
  );
}

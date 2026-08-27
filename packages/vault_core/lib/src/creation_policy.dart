// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';

enum VaultCreationCapability {
  additionalVault,
  customType,
  customField,
  totp,
  attachment,
}

abstract interface class VaultCreationPolicy {
  void requireAllowed(VaultCreationCapability capability);
}

final class CommunityFreeVaultCreationPolicy implements VaultCreationPolicy {
  const CommunityFreeVaultCreationPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {
    throw const VaultFailure(VaultFailureCode.capabilityUnavailable);
  }
}

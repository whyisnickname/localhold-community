// SPDX-License-Identifier: MPL-2.0

enum VaultFailureCode {
  invalidInput,
  invalidCredentials,
  unsupportedVersion,
  sessionNotFound,
  sessionLocked,
  reauthenticationRequired,
  cooldownActive,
  integrityFailure,
  payloadTooLarge,
  revisionConflict,
  objectNotFound,
  storageFull,
  migrationRequired,
  migrationFailed,
  readOnly,
  platformUnavailable,
  biometricUnavailable,
  biometricInvalidated,
  capabilityUnavailable,
  internalFailure,
}

final class VaultFailure implements Exception {
  const VaultFailure(this.code);

  final VaultFailureCode code;

  @override
  String toString() => 'VaultFailure(${code.name})';
}

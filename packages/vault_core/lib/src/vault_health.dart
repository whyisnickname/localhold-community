// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';

enum VaultHealthState { healthy, partiallyCorrupt, readOnly }

final class VaultHealthSnapshot {
  const VaultHealthSnapshot({
    required this.state,
    this.quarantinedObjectCount = 0,
    this.reason,
  });

  final VaultHealthState state;
  final int quarantinedObjectCount;
  final VaultFailureCode? reason;
}

final class VaultHealthController {
  VaultHealthSnapshot _snapshot = const VaultHealthSnapshot(
    state: VaultHealthState.healthy,
  );

  VaultHealthSnapshot get snapshot => _snapshot;
  bool get isReadOnly => _snapshot.state == VaultHealthState.readOnly;

  void recordObjectQuarantine() {
    if (_snapshot.state == VaultHealthState.readOnly) return;
    _snapshot = VaultHealthSnapshot(
      state: VaultHealthState.partiallyCorrupt,
      quarantinedObjectCount: _snapshot.quarantinedObjectCount + 1,
      reason: VaultFailureCode.integrityFailure,
    );
  }

  void enterReadOnly(VaultFailureCode reason) {
    if (reason != VaultFailureCode.integrityFailure &&
        reason != VaultFailureCode.migrationFailed &&
        reason != VaultFailureCode.storageFull &&
        reason != VaultFailureCode.readOnly) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    _snapshot = VaultHealthSnapshot(
      state: VaultHealthState.readOnly,
      quarantinedObjectCount: _snapshot.quarantinedObjectCount,
      reason: reason,
    );
  }

  void requireWritable() {
    if (_snapshot.state == VaultHealthState.readOnly) {
      throw const VaultFailure(VaultFailureCode.readOnly);
    }
  }
}

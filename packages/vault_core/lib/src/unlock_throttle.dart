// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';

final class UnlockThrottleState {
  const UnlockThrottleState({required this.failedAttempts, this.cooldownUntil});

  final int failedAttempts;
  final DateTime? cooldownUntil;
}

abstract interface class UnlockThrottleStore {
  Future<UnlockThrottleState> read(String vaultId);

  Future<void> write(String vaultId, UnlockThrottleState state);

  Future<void> clear(String vaultId);
}

final class PersistentUnlockThrottle {
  const PersistentUnlockThrottle({
    required this._store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final UnlockThrottleStore _store;
  final DateTime Function() _now;

  Future<UnlockThrottleState> state(String vaultId) => _store.read(vaultId);

  Future<void> requireAllowed(String vaultId) async {
    final state = await _store.read(vaultId);
    final until = state.cooldownUntil;
    if (until != null && _now().isBefore(until)) {
      throw const VaultFailure(VaultFailureCode.cooldownActive);
    }
  }

  Future<UnlockThrottleState> recordFailure(String vaultId) async {
    final current = await _store.read(vaultId);
    final failures = current.failedAttempts + 1;
    DateTime? until;
    if (failures >= 5) {
      final exponent = (failures - 5).clamp(0, 5);
      until = _now().add(Duration(seconds: (1 << exponent).clamp(1, 30)));
    }
    final updated = UnlockThrottleState(
      failedAttempts: failures,
      cooldownUntil: until,
    );
    await _store.write(vaultId, updated);
    return updated;
  }

  Future<void> recordSuccess(String vaultId) => _store.clear(vaultId);
}

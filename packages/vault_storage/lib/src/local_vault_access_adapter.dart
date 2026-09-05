// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:localhold_vault_access/localhold_vault_access.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_native/localhold_vault_native.dart';

import 'local_vault_runtime.dart';

/// Production local adapter for the Stage 5 access flow. Recovery words remain
/// native-owned; this object retains only the opaque ceremony capability.
final class LocalVaultAccessAdapter implements VaultAccessPort {
  factory LocalVaultAccessAdapter({
    required LocalVaultRuntime runtime,
    DateTime Function()? clock,
  }) => LocalVaultAccessAdapter._(runtime, clock ?? DateTime.now);

  LocalVaultAccessAdapter._(this._runtime, this._clock);

  final LocalVaultRuntime _runtime;
  final DateTime Function() _clock;
  RecoveryCeremony? _recovery;
  VaultId? _activeVaultId;

  @override
  Future<List<VaultUnlockEntry>> listLockedVaults() => _runtime.lockedVaults();

  @override
  Future<VaultId?> lastSelectedVault() => _runtime.lastSelectedVault();

  @override
  Future<void> createVault({
    required VaultId vaultId,
    required String name,
    required Uint8List masterPassword,
    required String? publicLockScreenLabel,
  }) async {
    final existing = await _runtime.lockedVaults();
    await _runtime.create(
      vaultId: vaultId,
      localizedName: name,
      masterPassword: masterPassword,
      now: _clock().toUtc(),
      isAdditionalVault: existing.isNotEmpty,
      publicLockScreenLabel: publicLockScreenLabel,
    );
    _activeVaultId = vaultId;
  }

  @override
  Future<void> unlockWithPassword({
    required VaultId vaultId,
    required Uint8List masterPassword,
  }) async {
    await _runtime.open(vaultId: vaultId, masterPassword: masterPassword);
    _activeVaultId = vaultId;
  }

  @override
  Future<void> unlockWithBiometric(VaultId vaultId) async {
    await _runtime.openWithBiometric(vaultId: vaultId);
    _activeVaultId = vaultId;
  }

  @override
  Future<void> recoverWithPhrase({
    required VaultId vaultId,
    required Uint8List recoveryPhraseUtf8,
    required Uint8List newMasterPassword,
  }) async {
    await _runtime.recover(
      vaultId: vaultId,
      recoveryPhraseUtf8: recoveryPhraseUtf8,
      newMasterPassword: newMasterPassword,
    );
    _activeVaultId = vaultId;
  }

  @override
  Future<VaultBiometricState> biometricState(VaultId vaultId) async {
    try {
      final status = await _runtime.biometricStatus(vaultId);
      if (status.invalidated) return VaultBiometricState.invalidated;
      return status.configured
          ? VaultBiometricState.configured
          : VaultBiometricState.available;
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.biometricUnavailable ||
          failure.code == VaultFailureCode.platformUnavailable) {
        return VaultBiometricState.unavailable;
      }
      rethrow;
    }
  }

  @override
  Future<List<int>> beginAndPresentRecovery() async {
    await cancelRecovery();
    final ceremony = await _runtime.beginRecovery();
    try {
      await _runtime.presentRecovery(ceremony);
      _recovery = ceremony;
      return List.unmodifiable(ceremony.challengePositions);
    } on Object {
      await _runtime.cancelRecovery(ceremony);
      rethrow;
    }
  }

  @override
  Future<void> confirmRecovery(Uint8List challengeWordsUtf8) async {
    final ceremony = _recovery;
    final vaultId = _activeVaultId;
    if (ceremony == null || vaultId == null) {
      throw const VaultFailure(VaultFailureCode.sessionLocked);
    }
    await _runtime.confirmRecovery(
      vaultId: vaultId,
      ceremony: ceremony,
      challengeWordsUtf8: challengeWordsUtf8,
    );
    _recovery = null;
  }

  @override
  Future<void> cancelRecovery() async {
    final ceremony = _recovery;
    _recovery = null;
    if (ceremony != null) await _runtime.cancelRecovery(ceremony);
  }

  @override
  Future<void> enableBiometric() => _runtime.enableBiometric();

  @override
  Future<void> lock() async {
    try {
      await cancelRecovery();
    } on Object {
      // Session destruction is the primary security action and must continue.
    }
    _activeVaultId = null;
    await _runtime.sessions.lock();
  }
}

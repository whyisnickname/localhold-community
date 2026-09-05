// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';

enum VaultBiometricState { unavailable, available, configured, invalidated }

/// Narrow application boundary implemented by the local runtime composition.
/// It has no account, backend, analytics, payment or network operation.
abstract interface class VaultAccessPort {
  Future<List<VaultUnlockEntry>> listLockedVaults();

  Future<VaultId?> lastSelectedVault();

  Future<void> createVault({
    required VaultId vaultId,
    required String name,
    required Uint8List masterPassword,
    required String? publicLockScreenLabel,
  });

  Future<void> unlockWithPassword({
    required VaultId vaultId,
    required Uint8List masterPassword,
  });

  Future<void> unlockWithBiometric(VaultId vaultId);

  Future<void> recoverWithPhrase({
    required VaultId vaultId,
    required Uint8List recoveryPhraseUtf8,
    required Uint8List newMasterPassword,
  });

  Future<VaultBiometricState> biometricState(VaultId vaultId);

  /// Presents native-owned recovery words and returns only non-secret challenge
  /// positions. The implementation retains the opaque ceremony capability.
  Future<List<int>> beginAndPresentRecovery();

  Future<void> confirmRecovery(Uint8List challengeWordsUtf8);

  Future<void> cancelRecovery();

  Future<void> enableBiometric();

  Future<void> lock();
}

void wipeBytes(Uint8List value) => value.fillRange(0, value.length, 0);

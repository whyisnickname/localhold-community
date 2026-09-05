// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_access/localhold_vault_access.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'onboarding_controller.dart';

enum VaultLaunchDestination { loading, onboarding, unlock, failure }

@immutable
final class VaultLaunchState {
  const VaultLaunchState({
    this.destination = VaultLaunchDestination.loading,
    this.issue,
  });

  final VaultLaunchDestination destination;
  final VaultAccessIssue? issue;
}

final class VaultLaunchController extends ChangeNotifier {
  VaultLaunchController({required VaultAccessPort port}) : _port = port;

  final VaultAccessPort _port;
  VaultLaunchState _state = const VaultLaunchState();

  VaultLaunchState get state => _state;

  Future<void> resolve() async {
    _set(const VaultLaunchState());
    try {
      final entries = await _port.listLockedVaults();
      _set(
        VaultLaunchState(
          destination: entries.isEmpty
              ? VaultLaunchDestination.onboarding
              : VaultLaunchDestination.unlock,
        ),
      );
    } on VaultFailure catch (failure) {
      _set(
        VaultLaunchState(
          destination: VaultLaunchDestination.failure,
          issue: mapVaultFailure(failure.code),
        ),
      );
    } on Object {
      _set(
        const VaultLaunchState(
          destination: VaultLaunchDestination.failure,
          issue: VaultAccessIssue.unknown,
        ),
      );
    }
  }

  void _set(VaultLaunchState value) {
    _state = value;
    notifyListeners();
  }
}

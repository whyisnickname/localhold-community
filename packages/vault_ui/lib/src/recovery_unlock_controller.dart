// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_access/localhold_vault_access.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'onboarding_controller.dart';

@immutable
final class RecoveryUnlockState {
  const RecoveryUnlockState({
    this.busy = false,
    this.complete = false,
    this.issue,
  });

  final bool busy;
  final bool complete;
  final VaultAccessIssue? issue;
}

final class RecoveryUnlockController extends ChangeNotifier {
  RecoveryUnlockController({
    required VaultAccessPort port,
    required VaultId vaultId,
    MasterPasswordPolicy? passwordPolicy,
  }) : _port = port,
       _vaultId = vaultId,
       _passwordPolicy = passwordPolicy ?? MasterPasswordPolicy();

  final VaultAccessPort _port;
  final VaultId _vaultId;
  final MasterPasswordPolicy _passwordPolicy;
  RecoveryUnlockState _state = const RecoveryUnlockState();

  RecoveryUnlockState get state => _state;

  Future<void> recover({
    required Uint8List recoveryPhraseUtf8,
    required Uint8List newMasterPassword,
  }) async {
    if (_state.busy) {
      wipeBytes(recoveryPhraseUtf8);
      wipeBytes(newMasterPassword);
      return;
    }
    try {
      final decoded = utf8.decode(newMasterPassword, allowMalformed: false);
      if (!_passwordPolicy.assess(decoded).accepted ||
          recoveryPhraseUtf8.isEmpty) {
        _set(const RecoveryUnlockState(issue: VaultAccessIssue.invalidInput));
        return;
      }
      _set(const RecoveryUnlockState(busy: true));
      await _port.recoverWithPhrase(
        vaultId: _vaultId,
        recoveryPhraseUtf8: recoveryPhraseUtf8,
        newMasterPassword: newMasterPassword,
      );
      _set(const RecoveryUnlockState(complete: true));
    } on FormatException {
      _set(const RecoveryUnlockState(issue: VaultAccessIssue.invalidInput));
    } on VaultFailure catch (failure) {
      _set(RecoveryUnlockState(issue: mapVaultFailure(failure.code)));
    } on Object {
      _set(const RecoveryUnlockState(issue: VaultAccessIssue.unknown));
    } finally {
      wipeBytes(recoveryPhraseUtf8);
      wipeBytes(newMasterPassword);
    }
  }

  void _set(RecoveryUnlockState value) {
    _state = value;
    notifyListeners();
  }
}

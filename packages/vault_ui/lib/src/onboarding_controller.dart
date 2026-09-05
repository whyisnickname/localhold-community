// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_access/localhold_vault_access.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

enum OnboardingStep {
  trust,
  masterPassword,
  recoveryChoice,
  recoveryChallenge,
  biometrics,
  complete,
}

enum VaultAccessIssue {
  invalidInput,
  invalidCredentials,
  cooldown,
  storageFull,
  readOnly,
  biometricUnavailable,
  biometricInvalidated,
  unavailable,
  integrityFailure,
  unknown,
}

@immutable
final class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.trust,
    this.busy = false,
    this.issue,
    this.vaultId,
    this.recoveryPositions = const [],
    this.recoveryConfigured = false,
    this.recoverySkipped = false,
    this.biometricConfigured = false,
  });

  final OnboardingStep step;
  final bool busy;
  final VaultAccessIssue? issue;
  final VaultId? vaultId;
  final List<int> recoveryPositions;
  final bool recoveryConfigured;
  final bool recoverySkipped;
  final bool biometricConfigured;

  OnboardingState copyWith({
    OnboardingStep? step,
    bool? busy,
    VaultAccessIssue? issue,
    bool clearIssue = false,
    VaultId? vaultId,
    List<int>? recoveryPositions,
    bool? recoveryConfigured,
    bool? recoverySkipped,
    bool? biometricConfigured,
  }) => OnboardingState(
    step: step ?? this.step,
    busy: busy ?? this.busy,
    issue: clearIssue ? null : issue ?? this.issue,
    vaultId: vaultId ?? this.vaultId,
    recoveryPositions: List.unmodifiable(
      recoveryPositions ?? this.recoveryPositions,
    ),
    recoveryConfigured: recoveryConfigured ?? this.recoveryConfigured,
    recoverySkipped: recoverySkipped ?? this.recoverySkipped,
    biometricConfigured: biometricConfigured ?? this.biometricConfigured,
  );
}

final class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required VaultAccessPort port,
    MasterPasswordPolicy? passwordPolicy,
    VaultId Function()? createVaultId,
  }) : _port = port,
       _passwordPolicy = passwordPolicy ?? MasterPasswordPolicy(),
       _createVaultId = createVaultId ?? VaultId.generate;

  final VaultAccessPort _port;
  final MasterPasswordPolicy _passwordPolicy;
  final VaultId Function() _createVaultId;
  OnboardingState _state = const OnboardingState();
  bool _recoveryMayBeActive = false;
  bool _disposed = false;

  OnboardingState get state => _state;

  void chooseGuest() => _set(
    _state.copyWith(step: OnboardingStep.masterPassword, clearIssue: true),
  );

  void backToTrust() =>
      _set(_state.copyWith(step: OnboardingStep.trust, clearIssue: true));

  Future<void> createLocalVault({
    required String name,
    required Uint8List masterPassword,
    required bool showNameWhileLocked,
  }) async {
    if (_state.busy || _state.step != OnboardingStep.masterPassword) {
      wipeBytes(masterPassword);
      return;
    }
    String decoded;
    try {
      decoded = utf8.decode(masterPassword, allowMalformed: false);
    } on FormatException {
      wipeBytes(masterPassword);
      _set(_state.copyWith(issue: VaultAccessIssue.invalidInput));
      return;
    }
    final assessment = _passwordPolicy.assess(decoded);
    decoded = '';
    if (!assessment.accepted ||
        name.trim().isEmpty ||
        name.runes.length > 256 ||
        (showNameWhileLocked &&
            name.trim().runes.length > VaultUnlockEntry.maximumLabelRunes)) {
      wipeBytes(masterPassword);
      _set(_state.copyWith(issue: VaultAccessIssue.invalidInput));
      return;
    }
    final id = _createVaultId();
    _set(_state.copyWith(busy: true, clearIssue: true));
    try {
      await _port.createVault(
        vaultId: id,
        name: name.trim(),
        masterPassword: masterPassword,
        publicLockScreenLabel: showNameWhileLocked ? name.trim() : null,
      );
      _set(
        _state.copyWith(
          step: OnboardingStep.recoveryChoice,
          busy: false,
          vaultId: id,
          clearIssue: true,
        ),
      );
    } on VaultFailure catch (failure) {
      _set(_state.copyWith(busy: false, issue: mapVaultFailure(failure.code)));
    } on Object {
      _set(_state.copyWith(busy: false, issue: VaultAccessIssue.unknown));
    } finally {
      wipeBytes(masterPassword);
    }
  }

  Future<void> beginRecovery() async {
    if (_state.busy || _state.step != OnboardingStep.recoveryChoice) return;
    _set(_state.copyWith(busy: true, clearIssue: true));
    _recoveryMayBeActive = true;
    try {
      final positions = await _port.beginAndPresentRecovery();
      if (_disposed) {
        await _port.cancelRecovery();
        _recoveryMayBeActive = false;
        return;
      }
      if (positions.isEmpty || positions.any((position) => position < 1)) {
        await _port.cancelRecovery();
        _recoveryMayBeActive = false;
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      _set(
        _state.copyWith(
          step: OnboardingStep.recoveryChallenge,
          busy: false,
          recoveryPositions: positions,
          clearIssue: true,
        ),
      );
    } on VaultFailure catch (failure) {
      _recoveryMayBeActive = false;
      _set(_state.copyWith(busy: false, issue: mapVaultFailure(failure.code)));
    } on Object {
      _recoveryMayBeActive = false;
      _set(_state.copyWith(busy: false, issue: VaultAccessIssue.unknown));
    }
  }

  Future<void> confirmRecovery(Uint8List challengeWordsUtf8) async {
    if (_state.busy || _state.step != OnboardingStep.recoveryChallenge) {
      wipeBytes(challengeWordsUtf8);
      return;
    }
    _set(_state.copyWith(busy: true, clearIssue: true));
    try {
      await _port.confirmRecovery(challengeWordsUtf8);
      _recoveryMayBeActive = false;
      _set(
        _state.copyWith(
          step: OnboardingStep.biometrics,
          busy: false,
          recoveryPositions: const [],
          recoveryConfigured: true,
          clearIssue: true,
        ),
      );
    } on VaultFailure catch (failure) {
      _set(_state.copyWith(busy: false, issue: mapVaultFailure(failure.code)));
    } on Object {
      _set(_state.copyWith(busy: false, issue: VaultAccessIssue.unknown));
    } finally {
      wipeBytes(challengeWordsUtf8);
    }
  }

  Future<void> cancelRecovery() async {
    if (_state.step != OnboardingStep.recoveryChallenge) return;
    try {
      await _port.cancelRecovery();
    } finally {
      _recoveryMayBeActive = false;
    }
    _set(
      _state.copyWith(
        step: OnboardingStep.recoveryChoice,
        recoveryPositions: const [],
        clearIssue: true,
      ),
    );
  }

  void skipRecovery() => _set(
    _state.copyWith(
      step: OnboardingStep.biometrics,
      recoverySkipped: true,
      clearIssue: true,
    ),
  );

  Future<void> enableBiometric() async {
    if (_state.busy || _state.step != OnboardingStep.biometrics) return;
    _set(_state.copyWith(busy: true, clearIssue: true));
    try {
      await _port.enableBiometric();
      _set(
        _state.copyWith(
          step: OnboardingStep.complete,
          busy: false,
          biometricConfigured: true,
          clearIssue: true,
        ),
      );
    } on VaultFailure catch (failure) {
      _set(_state.copyWith(busy: false, issue: mapVaultFailure(failure.code)));
    } on Object {
      _set(_state.copyWith(busy: false, issue: VaultAccessIssue.unknown));
    }
  }

  void skipBiometric() =>
      _set(_state.copyWith(step: OnboardingStep.complete, clearIssue: true));

  Future<void> interruptRecovery() async {
    if (_state.step != OnboardingStep.recoveryChallenge) return;
    try {
      await _port.cancelRecovery();
    } finally {
      _recoveryMayBeActive = false;
    }
    _set(
      _state.copyWith(
        step: OnboardingStep.recoveryChoice,
        busy: false,
        recoveryPositions: const [],
        clearIssue: true,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    if (_recoveryMayBeActive) {
      unawaited(_port.cancelRecovery());
      _recoveryMayBeActive = false;
    }
    super.dispose();
  }

  void _set(OnboardingState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }
}

VaultAccessIssue mapVaultFailure(VaultFailureCode code) => switch (code) {
  VaultFailureCode.invalidInput => VaultAccessIssue.invalidInput,
  VaultFailureCode.invalidCredentials => VaultAccessIssue.invalidCredentials,
  VaultFailureCode.cooldownActive => VaultAccessIssue.cooldown,
  VaultFailureCode.storageFull => VaultAccessIssue.storageFull,
  VaultFailureCode.readOnly => VaultAccessIssue.readOnly,
  VaultFailureCode.biometricUnavailable =>
    VaultAccessIssue.biometricUnavailable,
  VaultFailureCode.biometricInvalidated =>
    VaultAccessIssue.biometricInvalidated,
  VaultFailureCode.capabilityUnavailable ||
  VaultFailureCode.platformUnavailable => VaultAccessIssue.unavailable,
  VaultFailureCode.integrityFailure ||
  VaultFailureCode.unsupportedVersion ||
  VaultFailureCode.migrationFailed => VaultAccessIssue.integrityFailure,
  _ => VaultAccessIssue.unknown,
};

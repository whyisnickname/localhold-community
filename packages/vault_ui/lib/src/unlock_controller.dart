// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_access/localhold_vault_access.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'onboarding_controller.dart';

enum UnlockPhase { loading, locked, unlocking, unlocked }

@immutable
final class UnlockState {
  const UnlockState({
    this.phase = UnlockPhase.loading,
    this.entries = const [],
    this.selectedVaultId,
    this.biometricState = VaultBiometricState.unavailable,
    this.issue,
    this.cooldownUntil,
  });

  final UnlockPhase phase;
  final List<VaultUnlockEntry> entries;
  final VaultId? selectedVaultId;
  final VaultBiometricState biometricState;
  final VaultAccessIssue? issue;
  final DateTime? cooldownUntil;

  VaultUnlockEntry? get selectedEntry {
    final selected = selectedVaultId;
    if (selected == null) return null;
    for (final entry in entries) {
      if (entry.vaultId == selected) return entry;
    }
    return null;
  }

  UnlockState copyWith({
    UnlockPhase? phase,
    List<VaultUnlockEntry>? entries,
    VaultId? selectedVaultId,
    VaultBiometricState? biometricState,
    VaultAccessIssue? issue,
    bool clearIssue = false,
    DateTime? cooldownUntil,
  }) => UnlockState(
    phase: phase ?? this.phase,
    entries: List.unmodifiable(entries ?? this.entries),
    selectedVaultId: selectedVaultId ?? this.selectedVaultId,
    biometricState: biometricState ?? this.biometricState,
    issue: clearIssue ? null : issue ?? this.issue,
    cooldownUntil: cooldownUntil ?? this.cooldownUntil,
  );
}

final class UnlockController extends ChangeNotifier {
  UnlockController({required VaultAccessPort port}) : _port = port;

  final VaultAccessPort _port;
  UnlockState _state = const UnlockState();

  UnlockState get state => _state;

  Future<void> load() async {
    if (_state.phase == UnlockPhase.unlocking) return;
    _set(_state.copyWith(phase: UnlockPhase.loading, clearIssue: true));
    try {
      final entries = await _port.listLockedVaults();
      final lastSelected = await _port.lastSelectedVault();
      final selected = entries.any((entry) => entry.vaultId == lastSelected)
          ? lastSelected
          : entries.firstOrNull?.vaultId;
      final biometric = selected == null
          ? VaultBiometricState.unavailable
          : await _port.biometricState(selected);
      _state = UnlockState(
        phase: UnlockPhase.locked,
        entries: entries,
        selectedVaultId: selected,
        biometricState: biometric,
      );
      notifyListeners();
    } on VaultFailure catch (failure) {
      _set(
        UnlockState(
          phase: UnlockPhase.locked,
          issue: mapVaultFailure(failure.code),
        ),
      );
    } on Object {
      _set(
        const UnlockState(
          phase: UnlockPhase.locked,
          issue: VaultAccessIssue.unknown,
        ),
      );
    }
  }

  Future<void> selectVault(VaultId id) async {
    if (_state.phase == UnlockPhase.unlocking ||
        !_state.entries.any((entry) => entry.vaultId == id)) {
      return;
    }
    try {
      if (_state.phase == UnlockPhase.unlocked) await _port.lock();
      _set(
        _state.copyWith(
          phase: UnlockPhase.loading,
          selectedVaultId: id,
          clearIssue: true,
        ),
      );
      final biometric = await _port.biometricState(id);
      _set(
        _state.copyWith(
          phase: UnlockPhase.locked,
          selectedVaultId: id,
          biometricState: biometric,
          clearIssue: true,
        ),
      );
    } on VaultFailure catch (failure) {
      _set(
        _state.copyWith(
          phase: UnlockPhase.locked,
          issue: mapVaultFailure(failure.code),
        ),
      );
    } on Object {
      _set(
        _state.copyWith(
          phase: UnlockPhase.locked,
          issue: VaultAccessIssue.unknown,
        ),
      );
    }
  }

  Future<void> unlockWithPassword(Uint8List masterPassword) async {
    final id = _state.selectedVaultId;
    if (_state.phase == UnlockPhase.unlocking || id == null) {
      wipeBytes(masterPassword);
      return;
    }
    _set(_state.copyWith(phase: UnlockPhase.unlocking, clearIssue: true));
    try {
      await _port.unlockWithPassword(
        vaultId: id,
        masterPassword: masterPassword,
      );
      _set(_state.copyWith(phase: UnlockPhase.unlocked, clearIssue: true));
    } on VaultFailure catch (failure) {
      _set(
        _state.copyWith(
          phase: UnlockPhase.locked,
          issue: mapVaultFailure(failure.code),
        ),
      );
    } on Object {
      _set(
        _state.copyWith(
          phase: UnlockPhase.locked,
          issue: VaultAccessIssue.unknown,
        ),
      );
    } finally {
      wipeBytes(masterPassword);
    }
  }

  Future<void> unlockWithBiometric() async {
    final id = _state.selectedVaultId;
    if (_state.phase == UnlockPhase.unlocking ||
        id == null ||
        _state.biometricState != VaultBiometricState.configured) {
      return;
    }
    _set(_state.copyWith(phase: UnlockPhase.unlocking, clearIssue: true));
    try {
      await _port.unlockWithBiometric(id);
      _set(_state.copyWith(phase: UnlockPhase.unlocked, clearIssue: true));
    } on VaultFailure catch (failure) {
      _set(
        _state.copyWith(
          phase: UnlockPhase.locked,
          issue: mapVaultFailure(failure.code),
        ),
      );
    } on Object {
      _set(
        _state.copyWith(
          phase: UnlockPhase.locked,
          issue: VaultAccessIssue.unknown,
        ),
      );
    }
  }

  Future<void> lock() async {
    await _port.lock();
    _set(_state.copyWith(phase: UnlockPhase.locked, clearIssue: true));
  }

  void _set(UnlockState value) {
    _state = value;
    notifyListeners();
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'errors.dart';
import 'identifiers.dart';
import 'policies.dart';
import 'unlock_throttle.dart';

extension type const VaultSessionRef._(String value) {
  factory VaultSessionRef.fromOpaque(String value) {
    if (value.isEmpty || value.length > 128) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    return VaultSessionRef._(value);
  }
}

abstract interface class VaultKeyGateway {
  Future<VaultSessionRef> createVault({
    required VaultId vaultId,
    required Uint8List masterPassword,
  });

  Future<VaultSessionRef> openVault({
    required VaultId vaultId,
    required Uint8List masterPassword,
  });

  Future<void> close(VaultSessionRef session);

  Future<void> closeAll();
}

abstract interface class VaultSessionObserver {
  Future<void> onUnlocked(VaultId vaultId, VaultSessionRef session);

  Future<void> onLocking();

  Future<void> onBackground() async {}

  Future<void> onForeground() async {}
}

enum VaultSessionState {
  locked,
  unlocking,
  unlocked,
  reauthRequired,
  cooldown,
  readOnly,
  partiallyCorrupt,
  migrationRequired,
  migrationFailed,
  storageFull,
  biometricUnavailable,
  biometricInvalidated,
  sessionExpired,
  unsupportedVersion,
}

final class VaultSessionSnapshot {
  const VaultSessionSnapshot({
    required this.state,
    this.vaultId,
    this.safeResumeRoute,
    this.cooldownUntil,
  });

  final VaultSessionState state;
  final VaultId? vaultId;
  final String? safeResumeRoute;
  final DateTime? cooldownUntil;
}

final class VaultSessionCoordinator {
  VaultSessionCoordinator({
    required this._gateway,
    required this._unlockThrottle,
    this._foregroundDelay = AutoLockDelay.fiveMinutes,
    this._backgroundDelay = const Duration(seconds: 30),
    Iterable<VaultSessionObserver> observers = const [],
    DateTime Function()? clock,
  }) : _observers = List.of(observers),
       _clock = clock ?? DateTime.now;

  final VaultKeyGateway _gateway;
  final PersistentUnlockThrottle _unlockThrottle;
  final AutoLockDelay _foregroundDelay;
  final Duration _backgroundDelay;
  final List<VaultSessionObserver> _observers;
  final DateTime Function() _clock;
  final StreamController<VaultSessionSnapshot> _changes =
      StreamController.broadcast(sync: true);

  VaultSessionRef? _session;
  VaultId? _vaultId;
  Timer? _foregroundTimer;
  Timer? _backgroundTimer;
  DateTime? _backgroundedAt;
  String? _safeResumeRoute;
  DateTime? _cooldownUntil;
  VaultSessionState _state = VaultSessionState.locked;

  Stream<VaultSessionSnapshot> get changes => _changes.stream;
  VaultSessionState get state => _state;
  VaultSessionRef get requireSession =>
      _session ?? (throw const VaultFailure(VaultFailureCode.sessionLocked));

  /// Composition roots may register lifecycle-owned resources before the
  /// first vault is opened. Registration while a session exists is rejected so
  /// an observer can never miss the matching unlock transition.
  void addObserver(VaultSessionObserver observer) {
    if (_session != null || _state != VaultSessionState.locked) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  Future<void> open({
    required VaultId vaultId,
    required Uint8List masterPassword,
    String? safeResumeRoute,
  }) async {
    await lock();
    _state = VaultSessionState.unlocking;
    _emit();
    try {
      await _unlockThrottle.requireAllowed(vaultId.value);
      _session = await _gateway.openVault(
        vaultId: vaultId,
        masterPassword: masterPassword,
      );
      _vaultId = vaultId;
      _safeResumeRoute = _sanitizeRoute(safeResumeRoute);
      await _unlockThrottle.recordSuccess(vaultId.value);
      _cooldownUntil = null;
      _state = VaultSessionState.unlocked;
      for (final observer in _observers) {
        await observer.onUnlocked(vaultId, _session!);
      }
      recordActivity();
      _emit();
    } on VaultFailure catch (error) {
      final failedSession = _session;
      _session = null;
      _vaultId = null;
      _safeResumeRoute = null;
      await _discardFailedSession(failedSession);
      _state = _stateForFailure(error.code);
      if (error.code == VaultFailureCode.cooldownActive) {
        _cooldownUntil = (await _unlockThrottle.state(vaultId.value))
            .cooldownUntil;
      }
      if (error.code == VaultFailureCode.invalidCredentials) {
        final throttle = await _unlockThrottle.recordFailure(vaultId.value);
        _cooldownUntil = throttle.cooldownUntil;
        if (_cooldownUntil != null) {
          _state = VaultSessionState.cooldown;
        }
      }
      _emit();
      rethrow;
    }
  }

  Future<void> create({
    required VaultId vaultId,
    required Uint8List masterPassword,
    String? safeResumeRoute,
  }) async {
    await lock();
    _state = VaultSessionState.unlocking;
    _emit();
    try {
      _session = await _gateway.createVault(
        vaultId: vaultId,
        masterPassword: masterPassword,
      );
      _vaultId = vaultId;
      _safeResumeRoute = _sanitizeRoute(safeResumeRoute);
      _state = VaultSessionState.unlocked;
      for (final observer in _observers) {
        await observer.onUnlocked(vaultId, _session!);
      }
      await _unlockThrottle.recordSuccess(vaultId.value);
      recordActivity();
      _emit();
    } on VaultFailure {
      final failedSession = _session;
      _session = null;
      _vaultId = null;
      _safeResumeRoute = null;
      await _discardFailedSession(failedSession);
      _state = VaultSessionState.locked;
      _emit();
      rethrow;
    }
  }

  /// Activates a session created by a reviewed external unlock capability,
  /// such as a native biometric or recovery wrapper. The factory is invoked
  /// only after the previous session has been fully destroyed.
  Future<void> openUsing({
    required VaultId vaultId,
    required Future<VaultSessionRef> Function() openSession,
    String? safeResumeRoute,
  }) async {
    await lock();
    _state = VaultSessionState.unlocking;
    _emit();
    try {
      _session = await openSession();
      _vaultId = vaultId;
      _safeResumeRoute = _sanitizeRoute(safeResumeRoute);
      _cooldownUntil = null;
      _state = VaultSessionState.unlocked;
      for (final observer in _observers) {
        await observer.onUnlocked(vaultId, _session!);
      }
      recordActivity();
      _emit();
    } on VaultFailure catch (error) {
      final failedSession = _session;
      _session = null;
      _vaultId = null;
      _safeResumeRoute = null;
      await _discardFailedSession(failedSession);
      _state = _stateForFailure(error.code);
      _emit();
      rethrow;
    } on Object {
      final failedSession = _session;
      _session = null;
      _vaultId = null;
      _safeResumeRoute = null;
      await _discardFailedSession(failedSession);
      _state = VaultSessionState.locked;
      _emit();
      rethrow;
    }
  }

  void recordActivity() {
    if (_state != VaultSessionState.unlocked) return;
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer(_foregroundDelay.duration, () {
      unawaited(lock(terminalState: VaultSessionState.sessionExpired));
    });
  }

  Future<void> enterBackground() async {
    _foregroundTimer?.cancel();
    _backgroundTimer?.cancel();
    final backgroundedAt = _clock().toUtc();
    _backgroundedAt = backgroundedAt;
    for (final observer in _observers) {
      await observer.onBackground();
    }
    if (_session == null || _state != VaultSessionState.unlocked) return;
    final elapsed = _clock().toUtc().difference(backgroundedAt);
    if (elapsed.isNegative || elapsed >= _backgroundDelay) {
      await lock(terminalState: VaultSessionState.sessionExpired);
      return;
    }
    _backgroundTimer = Timer(_backgroundDelay - elapsed, () {
      unawaited(lock(terminalState: VaultSessionState.sessionExpired));
    });
  }

  Future<void> enterForeground() async {
    _backgroundTimer?.cancel();
    if (_session == null || _state != VaultSessionState.unlocked) return;
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt != null) {
      final elapsed = _clock().toUtc().difference(backgroundedAt);
      if (elapsed.isNegative || elapsed >= _backgroundDelay) {
        await lock(terminalState: VaultSessionState.sessionExpired);
        return;
      }
    }
    for (final observer in _observers) {
      await observer.onForeground();
    }
    recordActivity();
  }

  Future<void> onOperatingSystemLock() => lock();

  Future<void> lock({
    VaultSessionState terminalState = VaultSessionState.locked,
  }) async {
    _foregroundTimer?.cancel();
    _backgroundTimer?.cancel();
    _backgroundedAt = null;
    final session = _session;
    _session = null;
    _vaultId = null;
    _state = terminalState;
    Object? observerError;
    StackTrace? observerStack;
    try {
      if (session != null) {
        for (final observer in _observers) {
          try {
            await observer.onLocking();
          } catch (error, stack) {
            observerError ??= error;
            observerStack ??= stack;
          }
        }
      }
    } finally {
      try {
        if (session != null) {
          await _gateway.close(session);
        } else {
          await _gateway.closeAll();
        }
      } finally {
        _emit();
      }
    }
    if (observerError != null) {
      Error.throwWithStackTrace(observerError, observerStack!);
    }
  }

  Future<void> dispose() async {
    await lock();
    await _changes.close();
  }

  String? _sanitizeRoute(String? route) {
    if (route == null) return null;
    if (!RegExp(r'^/[a-z0-9/_-]{1,120}$').hasMatch(route)) return null;
    return route;
  }

  void _emit() {
    if (_changes.isClosed) return;
    _changes.add(
      VaultSessionSnapshot(
        state: _state,
        vaultId: _vaultId,
        safeResumeRoute: _safeResumeRoute,
        cooldownUntil: _cooldownUntil,
      ),
    );
  }

  Future<void> _discardFailedSession(VaultSessionRef? session) async {
    if (session == null) return;
    for (final observer in _observers) {
      try {
        await observer.onLocking();
      } on Object {
        // Cleanup must continue so another observer cannot retain plaintext.
      }
    }
    try {
      await _gateway.close(session);
    } finally {
      await _gateway.closeAll();
    }
  }

  VaultSessionState _stateForFailure(VaultFailureCode code) => switch (code) {
    VaultFailureCode.cooldownActive => VaultSessionState.cooldown,
    VaultFailureCode.readOnly => VaultSessionState.readOnly,
    VaultFailureCode.migrationRequired => VaultSessionState.migrationRequired,
    VaultFailureCode.migrationFailed => VaultSessionState.migrationFailed,
    VaultFailureCode.storageFull => VaultSessionState.storageFull,
    VaultFailureCode.biometricUnavailable =>
      VaultSessionState.biometricUnavailable,
    VaultFailureCode.biometricInvalidated =>
      VaultSessionState.biometricInvalidated,
    VaultFailureCode.unsupportedVersion => VaultSessionState.unsupportedVersion,
    VaultFailureCode.reauthenticationRequired =>
      VaultSessionState.reauthRequired,
    _ => VaultSessionState.locked,
  };
}

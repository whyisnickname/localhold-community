// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'errors.dart';
import 'identifiers.dart';
import 'session.dart';

enum ClipboardExpiry {
  fifteenSeconds(15),
  thirtySeconds(30),
  sixtySeconds(60),
  oneHundredTwentySeconds(120);

  const ClipboardExpiry(this.seconds);
  final int seconds;
}

abstract interface class VaultPrivacyGateway {
  Future<void> setVaultPrivacyActive(bool active);

  Future<void> copySensitive({
    required Uint8List utf8Value,
    required ClipboardExpiry expiry,
  });

  Future<void> clearSensitiveClipboard();
}

final class PrivacyLifecycleCoordinator {
  const PrivacyLifecycleCoordinator(this._gateway);

  final VaultPrivacyGateway _gateway;

  Future<void> onVaultUnlocked() => _gateway.setVaultPrivacyActive(true);

  Future<void> onVaultLocked() async {
    await _gateway.clearSensitiveClipboard();
    await _gateway.setVaultPrivacyActive(false);
  }

  Future<void> copy({
    required Uint8List utf8Value,
    ClipboardExpiry expiry = ClipboardExpiry.thirtySeconds,
  }) => _gateway.copySensitive(utf8Value: utf8Value, expiry: expiry);
}

final class PrivacySessionObserver implements VaultSessionObserver {
  const PrivacySessionObserver(this._coordinator);

  final PrivacyLifecycleCoordinator _coordinator;

  @override
  Future<void> onUnlocked(VaultId vaultId, VaultSessionRef session) =>
      _coordinator.onVaultUnlocked();

  @override
  Future<void> onLocking() => _coordinator.onVaultLocked();

  @override
  Future<void> onBackground() async {}

  @override
  Future<void> onForeground() async {}
}

final class RevealAuthorization {
  RevealAuthorization({this._validity = const Duration(minutes: 5)});

  final Duration _validity;
  DateTime? _authorizedAt;

  bool isAuthorized(DateTime now) {
    if (_authorizedAt == null) return false;
    final elapsed = now.toUtc().difference(_authorizedAt!);
    return !elapsed.isNegative && elapsed <= _validity;
  }

  void authorize(DateTime now) => _authorizedAt = now.toUtc();

  void clear() => _authorizedAt = null;
}

final class RevealAuthorizationObserver implements VaultSessionObserver {
  const RevealAuthorizationObserver(this._authorization);

  final RevealAuthorization _authorization;

  @override
  Future<void> onUnlocked(VaultId vaultId, VaultSessionRef session) async {
    _authorization.clear();
  }

  @override
  Future<void> onBackground() async {
    _authorization.clear();
  }

  @override
  Future<void> onForeground() async {}

  @override
  Future<void> onLocking() async {
    _authorization.clear();
  }
}

final class MasterCredentialFreshness {
  MasterCredentialFreshness({this._maximumAge = const Duration(days: 30)});

  final Duration _maximumAge;
  DateTime? _verifiedAt;

  bool requiresMasterCredential(DateTime now) {
    if (_verifiedAt == null) return true;
    final elapsed = now.toUtc().difference(_verifiedAt!);
    return elapsed.isNegative || elapsed > _maximumAge;
  }

  void markVerified(DateTime now) => _verifiedAt = now.toUtc();

  void clear() => _verifiedAt = null;
}

final class SensitiveRevealSnapshot {
  const SensitiveRevealSnapshot({
    required this.revealAll,
    required this.revealedFieldIds,
  });

  final bool revealAll;
  final Set<String> revealedFieldIds;

  bool isRevealed(String fieldId) =>
      revealAll || revealedFieldIds.contains(fieldId);
}

/// Stores only opaque field IDs. Plaintext remains owned by the caller and UI.
/// Timers are defense-in-depth; lifecycle callbacks clear state synchronously.
final class SensitiveRevealController implements VaultSessionObserver {
  SensitiveRevealController({
    Duration fieldDuration = const Duration(seconds: 15),
    Duration allDuration = const Duration(seconds: 30),
  }) : _fieldDuration = fieldDuration,
       _allDuration = allDuration {
    if (fieldDuration.isNegative || allDuration.isNegative) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final Duration _fieldDuration;
  final Duration _allDuration;
  final Map<String, Timer> _fieldTimers = {};
  final StreamController<SensitiveRevealSnapshot> _changes =
      StreamController.broadcast(sync: true);
  Timer? _allTimer;
  bool _revealAll = false;
  bool _active = false;

  Stream<SensitiveRevealSnapshot> get changes => _changes.stream;

  SensitiveRevealSnapshot get snapshot => SensitiveRevealSnapshot(
    revealAll: _revealAll,
    revealedFieldIds: Set.unmodifiable(_fieldTimers.keys),
  );

  void revealField(String fieldId) {
    _requireActive();
    if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(fieldId)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    _fieldTimers.remove(fieldId)?.cancel();
    _fieldTimers[fieldId] = Timer(_fieldDuration, () {
      _fieldTimers.remove(fieldId);
      _emit();
    });
    _emit();
  }

  void revealAll() {
    _requireActive();
    _allTimer?.cancel();
    _revealAll = true;
    _allTimer = Timer(_allDuration, () {
      _revealAll = false;
      _allTimer = null;
      _emit();
    });
    _emit();
  }

  void hideAll() {
    _allTimer?.cancel();
    _allTimer = null;
    _revealAll = false;
    for (final timer in _fieldTimers.values) {
      timer.cancel();
    }
    _fieldTimers.clear();
    _emit();
  }

  Future<void> dispose() async {
    _active = false;
    hideAll();
    await _changes.close();
  }

  @override
  Future<void> onUnlocked(VaultId vaultId, VaultSessionRef session) async {
    hideAll();
    _active = true;
  }

  @override
  Future<void> onBackground() async {
    _active = false;
    hideAll();
  }

  @override
  Future<void> onForeground() async {
    hideAll();
    _active = true;
  }

  @override
  Future<void> onLocking() async {
    _active = false;
    hideAll();
  }

  void _requireActive() {
    if (!_active) {
      throw const VaultFailure(VaultFailureCode.sessionLocked);
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(snapshot);
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test('switching vault destroys the previous session first', () async {
    final gateway = _Gateway();
    final observer = _Observer();
    final coordinator = VaultSessionCoordinator(
      gateway: gateway,
      unlockThrottle: PersistentUnlockThrottle(store: _ThrottleStore()),
      foregroundDelay: AutoLockDelay.thirtyMinutes,
      observers: [observer],
    );
    addTearDown(() => coordinator.dispose());

    final first = VaultId.generate();
    final second = VaultId.generate();
    await coordinator.create(
      vaultId: first,
      masterPassword: Uint8List.fromList([1]),
    );
    final firstSession = coordinator.requireSession.value;
    await coordinator.open(
      vaultId: second,
      masterPassword: Uint8List.fromList([2]),
      safeResumeRoute: '/records/safe-id',
    );

    expect(gateway.closed, contains(firstSession));
    expect(observer.lockCount, 1);
    expect(observer.unlockedVaults, [first.value, second.value]);
    expect(coordinator.state, VaultSessionState.unlocked);
  });

  test(
    'external biometric or recovery session uses normal lifecycle',
    () async {
      final gateway = _Gateway();
      final observer = _Observer();
      final coordinator = VaultSessionCoordinator(
        gateway: gateway,
        unlockThrottle: PersistentUnlockThrottle(store: _ThrottleStore()),
        observers: [observer],
      );
      addTearDown(() => coordinator.dispose());
      final vaultId = VaultId.generate();

      await coordinator.openUsing(
        vaultId: vaultId,
        openSession: gateway.external,
      );
      expect(coordinator.state, VaultSessionState.unlocked);
      expect(observer.unlockedVaults, [vaultId.value]);
      await coordinator.onOperatingSystemLock();
      expect(coordinator.state, VaultSessionState.locked);
      expect(gateway.closed, isNotEmpty);
    },
  );

  test(
    'foreground fails closed when the Dart background timer was suspended',
    () async {
      var now = DateTime.utc(2026, 1, 1);
      final gateway = _Gateway();
      final coordinator = VaultSessionCoordinator(
        gateway: gateway,
        unlockThrottle: PersistentUnlockThrottle(store: _ThrottleStore()),
        backgroundDelay: const Duration(seconds: 30),
        clock: () => now,
      );
      addTearDown(() => coordinator.dispose());
      await coordinator.create(
        vaultId: VaultId.generate(),
        masterPassword: Uint8List.fromList(List.filled(15, 1)),
      );
      await coordinator.enterBackground();
      now = now.add(const Duration(seconds: 31));

      await coordinator.enterForeground();

      expect(coordinator.state, VaultSessionState.sessionExpired);
      expect(gateway.closed, isNotEmpty);
    },
  );

  test('persistent cooldown caps at 30 seconds', () async {
    final now = DateTime.utc(2026, 8, 26);
    final throttle = PersistentUnlockThrottle(
      store: _ThrottleStore(),
      now: () => now,
    );
    UnlockThrottleState state = const UnlockThrottleState(failedAttempts: 0);
    for (var index = 0; index < 20; index++) {
      state = await throttle.recordFailure('vault');
    }
    expect(state.failedAttempts, 20);
    expect(state.cooldownUntil!.difference(now), const Duration(seconds: 30));
    await expectLater(
      throttle.requireAllowed('vault'),
      throwsA(
        isA<VaultFailure>().having(
          (error) => error.code,
          'code',
          VaultFailureCode.cooldownActive,
        ),
      ),
    );
  });
}

final class _Gateway implements VaultKeyGateway {
  var _next = 0;
  final List<String> closed = [];

  VaultSessionRef _new() => VaultSessionRef.fromOpaque('session-${_next++}');

  Future<VaultSessionRef> external() async => _new();

  @override
  Future<VaultSessionRef> createVault({
    required VaultId vaultId,
    required Uint8List masterPassword,
  }) async => _new();

  @override
  Future<VaultSessionRef> openVault({
    required VaultId vaultId,
    required Uint8List masterPassword,
  }) async => _new();

  @override
  Future<void> close(VaultSessionRef session) async {
    closed.add(session.value);
  }

  @override
  Future<void> closeAll() async {}
}

final class _Observer implements VaultSessionObserver {
  final List<String> unlockedVaults = [];
  var lockCount = 0;

  @override
  Future<void> onUnlocked(VaultId vaultId, VaultSessionRef session) async {
    unlockedVaults.add(vaultId.value);
  }

  @override
  Future<void> onLocking() async {
    lockCount++;
  }

  @override
  Future<void> onBackground() async {}

  @override
  Future<void> onForeground() async {}
}

final class _ThrottleStore implements UnlockThrottleStore {
  final Map<String, UnlockThrottleState> values = {};

  @override
  Future<void> clear(String vaultId) async {
    values.remove(vaultId);
  }

  @override
  Future<UnlockThrottleState> read(String vaultId) async =>
      values[vaultId] ?? const UnlockThrottleState(failedAttempts: 0);

  @override
  Future<void> write(String vaultId, UnlockThrottleState state) async {
    values[vaultId] = state;
  }
}

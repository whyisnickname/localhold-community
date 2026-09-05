// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test(
    'guest onboarding creates one local vault and wipes password bytes',
    () async {
      final port = _FakeVaultAccessPort();
      final id = VaultId.generate();
      final controller = OnboardingController(
        port: port,
        createVaultId: () => id,
      )..chooseGuest();
      final password = Uint8List.fromList(
        'a-strong-local-master-password'.codeUnits,
      );

      await controller.createLocalVault(
        name: 'Personal',
        masterPassword: password,
        showNameWhileLocked: false,
      );

      expect(controller.state.step, OnboardingStep.recoveryChoice);
      expect(controller.state.vaultId, id);
      expect(port.created, 1);
      expect(port.publicLabel, isNull);
      expect(password, everyElement(0));
      expect(port.lastPasswordReference, everyElement(0));
    },
  );

  test('explicit public label is bounded and never inferred', () async {
    final port = _FakeVaultAccessPort();
    final controller = OnboardingController(port: port)..chooseGuest();
    final password = Uint8List.fromList(
      'a-strong-local-master-password'.codeUnits,
    );

    await controller.createLocalVault(
      name: 'P' * 81,
      masterPassword: password,
      showNameWhileLocked: true,
    );

    expect(controller.state.issue, VaultAccessIssue.invalidInput);
    expect(port.created, 0);
    expect(password, everyElement(0));
  });

  test(
    'recovery state contains positions only and challenge bytes are wiped',
    () async {
      final port = _FakeVaultAccessPort();
      final controller = OnboardingController(port: port)..chooseGuest();
      await controller.createLocalVault(
        name: 'Local',
        masterPassword: Uint8List.fromList(
          'a-strong-local-master-password'.codeUnits,
        ),
        showNameWhileLocked: false,
      );

      await controller.beginRecovery();
      expect(controller.state.step, OnboardingStep.recoveryChallenge);
      expect(controller.state.recoveryPositions, [3, 8, 11]);

      final challenge = Uint8List.fromList('alpha\nbeta\ngamma'.codeUnits);
      await controller.confirmRecovery(challenge);

      expect(controller.state.step, OnboardingStep.biometrics);
      expect(controller.state.recoveryPositions, isEmpty);
      expect(controller.state.recoveryConfigured, isTrue);
      expect(challenge, everyElement(0));
    },
  );

  test('interrupted recovery cancels ceremony and forgets positions', () async {
    final port = _FakeVaultAccessPort();
    final controller = OnboardingController(port: port)..chooseGuest();
    await controller.createLocalVault(
      name: 'Local',
      masterPassword: Uint8List.fromList(
        'a-strong-local-master-password'.codeUnits,
      ),
      showNameWhileLocked: false,
    );
    await controller.beginRecovery();

    await controller.interruptRecovery();

    expect(port.recoveryCancellations, 1);
    expect(controller.state.step, OnboardingStep.recoveryChoice);
    expect(controller.state.recoveryPositions, isEmpty);
  });

  test('invalid recovery positions cancel the opaque ceremony', () async {
    final port = _FakeVaultAccessPort(recoveryPositions: const [0]);
    final controller = OnboardingController(port: port)..chooseGuest();
    await controller.createLocalVault(
      name: 'Local',
      masterPassword: Uint8List.fromList(
        'a-strong-local-master-password'.codeUnits,
      ),
      showNameWhileLocked: false,
    );

    await controller.beginRecovery();

    expect(port.recoveryCancellations, 1);
    expect(controller.state.issue, VaultAccessIssue.integrityFailure);
    expect(controller.state.recoveryPositions, isEmpty);
  });

  test(
    'busy onboarding rejects duplicate create intent and wipes both inputs',
    () async {
      final wait = Completer<void>();
      final port = _FakeVaultAccessPort(createWait: wait.future);
      final controller = OnboardingController(port: port)..chooseGuest();
      final first = Uint8List.fromList(
        'first-strong-master-password'.codeUnits,
      );
      final second = Uint8List.fromList(
        'second-strong-master-password'.codeUnits,
      );

      final pending = controller.createLocalVault(
        name: 'Vault',
        masterPassword: first,
        showNameWhileLocked: false,
      );
      await Future<void>.delayed(Duration.zero);
      await controller.createLocalVault(
        name: 'Vault',
        masterPassword: second,
        showNameWhileLocked: false,
      );
      wait.complete();
      await pending;

      expect(port.created, 1);
      expect(first, everyElement(0));
      expect(second, everyElement(0));
    },
  );

  test('unlock selects last vault, maps failure and wipes password', () async {
    final first = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 1);
    final second = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 2);
    final port = _FakeVaultAccessPort(
      entries: [first, second],
      lastSelected: second.vaultId,
      unlockFailure: const VaultFailure(VaultFailureCode.invalidCredentials),
    );
    final controller = UnlockController(port: port);

    await controller.load();
    expect(controller.state.selectedVaultId, second.vaultId);

    final password = Uint8List.fromList('incorrect-secret'.codeUnits);
    await controller.unlockWithPassword(password);
    expect(controller.state.phase, UnlockPhase.locked);
    expect(controller.state.issue, VaultAccessIssue.invalidCredentials);
    expect(password, everyElement(0));
  });

  test(
    'changing vault from an unlocked state destroys the old session',
    () async {
      final first = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 1);
      final second = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 2);
      final port = _FakeVaultAccessPort(entries: [first, second]);
      final controller = UnlockController(port: port);
      await controller.load();
      await controller.unlockWithPassword(
        Uint8List.fromList('valid-local-master-password'.codeUnits),
      );

      await controller.selectVault(second.vaultId);

      expect(port.locks, 1);
      expect(controller.state.phase, UnlockPhase.locked);
      expect(controller.state.selectedVaultId, second.vaultId);
    },
  );

  test('vault switch lock failure returns a closed issue state', () async {
    final first = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 1);
    final second = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 2);
    final port = _FakeVaultAccessPort(
      entries: [first, second],
      lockFailure: StateError('provider detail'),
    );
    final controller = UnlockController(port: port);
    await controller.load();
    await controller.unlockWithPassword(
      Uint8List.fromList('valid-local-master-password'.codeUnits),
    );

    await controller.selectVault(second.vaultId);

    expect(controller.state.phase, UnlockPhase.locked);
    expect(controller.state.issue, VaultAccessIssue.unknown);
  });

  test('launch destination depends only on local directory presence', () async {
    final empty = VaultLaunchController(port: _FakeVaultAccessPort());
    await empty.resolve();
    expect(empty.state.destination, VaultLaunchDestination.onboarding);

    final existing = VaultLaunchController(
      port: _FakeVaultAccessPort(
        entries: [VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 1)],
      ),
    );
    await existing.resolve();
    expect(existing.state.destination, VaultLaunchDestination.unlock);
  });

  test('recovery unlock replaces password and wipes both buffers', () async {
    final port = _FakeVaultAccessPort();
    final controller = RecoveryUnlockController(
      port: port,
      vaultId: VaultId.generate(),
    );
    final phrase = Uint8List.fromList('one two three four'.codeUnits);
    final password = Uint8List.fromList(
      'replacement-master-password'.codeUnits,
    );

    await controller.recover(
      recoveryPhraseUtf8: phrase,
      newMasterPassword: password,
    );

    expect(controller.state.complete, isTrue);
    expect(port.recoveries, 1);
    expect(phrase, everyElement(0));
    expect(password, everyElement(0));
  });

  test('recovery input uses the native single-space wire contract', () {
    final encoded = encodeRecoveryWords('  alpha\nbeta   gamma  ');

    expect(String.fromCharCodes(encoded), 'alpha beta gamma');
  });
}

final class _FakeVaultAccessPort implements VaultAccessPort {
  _FakeVaultAccessPort({
    this.entries = const [],
    this.lastSelected,
    this.unlockFailure,
    this.createWait,
    this.recoveryPositions = const [3, 8, 11],
    this.lockFailure,
  });

  final List<VaultUnlockEntry> entries;
  final VaultId? lastSelected;
  final VaultFailure? unlockFailure;
  final Future<void>? createWait;
  final List<int> recoveryPositions;
  final Object? lockFailure;
  int created = 0;
  int locks = 0;
  int recoveries = 0;
  int recoveryCancellations = 0;
  String? publicLabel;
  Uint8List? lastPasswordReference;

  @override
  Future<List<int>> beginAndPresentRecovery() async => recoveryPositions;

  @override
  Future<void> cancelRecovery() async {
    recoveryCancellations++;
  }

  @override
  Future<void> confirmRecovery(Uint8List challengeWordsUtf8) async {}

  @override
  Future<void> createVault({
    required VaultId vaultId,
    required String name,
    required Uint8List masterPassword,
    required String? publicLockScreenLabel,
  }) async {
    created++;
    publicLabel = publicLockScreenLabel;
    lastPasswordReference = masterPassword;
    await createWait;
  }

  @override
  Future<void> enableBiometric() async {}

  @override
  Future<VaultBiometricState> biometricState(VaultId vaultId) async =>
      VaultBiometricState.configured;

  @override
  Future<VaultId?> lastSelectedVault() async => lastSelected;

  @override
  Future<List<VaultUnlockEntry>> listLockedVaults() async => entries;

  @override
  Future<void> recoverWithPhrase({
    required VaultId vaultId,
    required Uint8List recoveryPhraseUtf8,
    required Uint8List newMasterPassword,
  }) async {
    recoveries++;
  }

  @override
  Future<void> lock() async {
    locks++;
    if (lockFailure case final failure?) throw failure;
  }

  @override
  Future<void> unlockWithBiometric(VaultId vaultId) async {}

  @override
  Future<void> unlockWithPassword({
    required VaultId vaultId,
    required Uint8List masterPassword,
  }) async {
    if (unlockFailure case final failure?) throw failure;
  }
}

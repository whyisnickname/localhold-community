// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  testWidgets('onboarding reflows at 320 px and 200% Russian text', (
    tester,
  ) async {
    await _setSurface(tester, const Size(320, 720));
    final controller = OnboardingController(port: _WidgetPort());

    await tester.pumpWidget(
      _app(
        locale: const Locale('ru'),
        textScale: 2,
        child: OnboardingScreen(
          controller: controller,
          onOpenVault: () {},
          onAddFirstRecord: () {},
        ),
      ),
    );

    expect(
      find.text('Ваши данные остаются на этом устройстве'),
      findsOneWidget,
    );
    expect(find.text('Создать локальное хранилище'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked picker exposes public and neutral labels only', (
    tester,
  ) async {
    final first = VaultUnlockEntry(vaultId: VaultId.generate(), ordinal: 1);
    final second = VaultUnlockEntry(
      vaultId: VaultId.generate(),
      ordinal: 2,
      publicLabel: 'Travel',
    );
    final controller = UnlockController(
      port: _WidgetPort(entries: [first, second], lastSelected: first.vaultId),
    );

    await tester.pumpWidget(
      _app(
        child: UnlockScreen(
          controller: controller,
          onUnlocked: () {},
          onRecover: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vault 1'), findsOneWidget);
    await tester.tap(find.text('Choose vault'));
    await tester.pumpAndSettle();
    expect(find.text('Travel'), findsOneWidget);
    expect(find.textContaining('record'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home skeleton keeps empty recents actionable and safe', (
    tester,
  ) async {
    await _setSurface(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(
        textScale: 2,
        child: HomeSkeleton(
          model: const HomeSkeletonModel(
            safetyStatus: HomeSafetyStatus.recoveryMissing,
          ),
          onSafetyAction: () {},
          onQuickFilter: (_) {},
          onType: (_) {},
          onRecent: (_) {},
          onChooseVault: () {},
        ),
      ),
    );

    expect(
      find.text('Create recovery words to protect access'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Recent records will appear here'),
      240,
    );
    expect(find.text('Recent records will appear here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required Widget child,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: LocalholdLocalizations.supportedLocales,
  localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
  theme: LocalholdTheme.light(),
  builder: (context, value) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: value!,
  ),
  home: child,
);

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

final class _WidgetPort implements VaultAccessPort {
  _WidgetPort({this.entries = const [], this.lastSelected});

  final List<VaultUnlockEntry> entries;
  final VaultId? lastSelected;

  @override
  Future<List<int>> beginAndPresentRecovery() async => [1, 2, 3];

  @override
  Future<void> cancelRecovery() async {}

  @override
  Future<void> confirmRecovery(Uint8List challengeWordsUtf8) async {}

  @override
  Future<void> createVault({
    required VaultId vaultId,
    required String name,
    required Uint8List masterPassword,
    required String? publicLockScreenLabel,
  }) async {}

  @override
  Future<void> enableBiometric() async {}

  @override
  Future<VaultBiometricState> biometricState(VaultId vaultId) async =>
      VaultBiometricState.unavailable;

  @override
  Future<VaultId?> lastSelectedVault() async => lastSelected;

  @override
  Future<List<VaultUnlockEntry>> listLockedVaults() async => entries;

  @override
  Future<void> recoverWithPhrase({
    required VaultId vaultId,
    required Uint8List recoveryPhraseUtf8,
    required Uint8List newMasterPassword,
  }) async {}

  @override
  Future<void> lock() async {}

  @override
  Future<void> unlockWithBiometric(VaultId vaultId) async {}

  @override
  Future<void> unlockWithPassword({
    required VaultId vaultId,
    required Uint8List masterPassword,
  }) async {}
}

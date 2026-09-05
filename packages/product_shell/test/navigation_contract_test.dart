// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_product_shell/localhold_product_shell.dart';

void main() {
  test('destination order is stable and contains exactly four entries', () {
    expect(LocalholdDestination.values, const <LocalholdDestination>[
      LocalholdDestination.vault,
      LocalholdDestination.subscriptions,
      LocalholdDestination.security,
      LocalholdDestination.settings,
    ]);
  });

  test('cold unlock always opens Home', () {
    final selected = LocalholdNavigationReducer.selectDestination(
      const LocalholdNavigationState.unlockedHome(),
      LocalholdDestination.settings,
    );
    final unlocked = LocalholdNavigationReducer.unlock(
      LocalholdNavigationReducer.lock(selected),
      LocalholdUnlockKind.cold,
    );

    expect(unlocked.isLocked, isFalse);
    expect(unlocked.destination, LocalholdDestination.vault);
    expect(unlocked.leaf, LocalholdSafeLeaf.vaultHome);
  });

  test('warm unlock keeps only the safe destination overview', () {
    final records = LocalholdNavigationReducer.openLeaf(
      const LocalholdNavigationState.unlockedHome(),
      LocalholdSafeLeaf.allRecords,
    );
    final unlocked = LocalholdNavigationReducer.unlock(
      LocalholdNavigationReducer.lock(records),
      LocalholdUnlockKind.warm,
    );

    expect(unlocked.destination, LocalholdDestination.vault);
    expect(unlocked.leaf, LocalholdSafeLeaf.vaultHome);
  });

  test('locked navigation ignores destination and leaf intents', () {
    const locked = LocalholdNavigationState.locked();

    expect(
      LocalholdNavigationReducer.selectDestination(
        locked,
        LocalholdDestination.security,
      ),
      same(locked),
    );
    expect(
      LocalholdNavigationReducer.openLeaf(locked, LocalholdSafeLeaf.trash),
      same(locked),
    );
  });

  test('safe route serialization contains no arbitrary navigation payload', () {
    const descriptor = LocalholdSafeRouteDescriptor(
      leaf: LocalholdSafeLeaf.archive,
    );
    final encoded = LocalholdSafeRouteCodec.encode(descriptor);
    final json = jsonDecode(encoded) as Map<String, Object?>;

    expect(
      json.keys,
      unorderedEquals(<String>['version', 'destination', 'leaf']),
    );
    expect(
      LocalholdSafeRouteCodec.decode(encoded).leaf,
      LocalholdSafeLeaf.archive,
    );
  });

  test('malformed, mismatched and future routes fail closed to Home', () {
    const badValues = <String>[
      'not-json',
      '{"version":2,"destination":"settings","leaf":"settingsOverview"}',
      '{"version":1,"destination":"security","leaf":"trash"}',
      '{"version":1,"destination":"unknown","leaf":"trash"}',
    ];

    for (final encoded in badValues) {
      final route = LocalholdSafeRouteCodec.decode(encoded);
      expect(route.destination, LocalholdDestination.vault);
      expect(route.leaf, LocalholdSafeLeaf.vaultHome);
    }
  });

  test('controller emits only when an unlocked transition changes state', () {
    final controller = LocalholdNavigationController(
      initialState: const LocalholdNavigationState.locked(),
    );
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.selectDestination(LocalholdDestination.settings);
    expect(notifications, 0);
    controller.unlock(LocalholdUnlockKind.warm);
    expect(notifications, 1);
    controller.selectDestination(LocalholdDestination.settings);
    expect(notifications, 2);

    controller.dispose();
  });
}

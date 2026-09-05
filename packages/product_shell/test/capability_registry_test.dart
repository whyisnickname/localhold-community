// SPDX-License-Identifier: MPL-2.0
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_product_shell/localhold_product_shell.dart';

void main() {
  test('community capability registry fails closed for every gated action', () {
    const registry = StaticLocalholdCapabilityRegistry.community();

    for (final capability in LocalholdGatedCapability.values) {
      final decision = registry.decisionFor(capability);
      expect(
        decision.availability,
        LocalholdCapabilityAvailability.unavailableInBuild,
      );
      expect(decision.canCreate, isFalse);
    }
  });

  test('explicit availability never changes an unspecified capability', () {
    const registry = StaticLocalholdCapabilityRegistry(
      <LocalholdGatedCapability, LocalholdCapabilityDecision>{
        LocalholdGatedCapability.customField:
            LocalholdCapabilityDecision.available(),
      },
    );

    expect(
      registry.decisionFor(LocalholdGatedCapability.customField).canCreate,
      isTrue,
    );
    expect(
      registry
          .decisionFor(LocalholdGatedCapability.subscriptionAnalytics)
          .canCreate,
      isFalse,
    );
  });
}

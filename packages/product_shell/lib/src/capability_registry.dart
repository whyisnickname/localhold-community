// SPDX-License-Identifier: MPL-2.0

enum LocalholdGatedCapability {
  customType,
  customField,
  newAttachment,
  newTotp,
  savedFilter,
  reminderSchedule,
  subscriptionAnalytics,
  dependencyGraph,
  protectedSecurityAnalysis,
}

enum LocalholdCapabilityAvailability {
  available,
  entitlementRequired,
  expiredReadOnly,
  unavailableInBuild,
  platformUnsupported,
}

final class LocalholdCapabilityDecision {
  const LocalholdCapabilityDecision(this.availability);

  const LocalholdCapabilityDecision.available()
    : availability = LocalholdCapabilityAvailability.available;

  const LocalholdCapabilityDecision.unavailable()
    : availability = LocalholdCapabilityAvailability.unavailableInBuild;

  final LocalholdCapabilityAvailability availability;

  bool get canCreate =>
      availability == LocalholdCapabilityAvailability.available;
}

abstract interface class LocalholdCapabilityRegistry {
  LocalholdCapabilityDecision decisionFor(LocalholdGatedCapability capability);
}

final class StaticLocalholdCapabilityRegistry
    implements LocalholdCapabilityRegistry {
  const StaticLocalholdCapabilityRegistry(
    this._decisions, {
    this.fallback = const LocalholdCapabilityDecision.unavailable(),
  });

  const StaticLocalholdCapabilityRegistry.community()
    : _decisions =
          const <LocalholdGatedCapability, LocalholdCapabilityDecision>{},
      fallback = const LocalholdCapabilityDecision.unavailable();

  final Map<LocalholdGatedCapability, LocalholdCapabilityDecision> _decisions;
  final LocalholdCapabilityDecision fallback;

  @override
  LocalholdCapabilityDecision decisionFor(
    LocalholdGatedCapability capability,
  ) => _decisions[capability] ?? fallback;
}

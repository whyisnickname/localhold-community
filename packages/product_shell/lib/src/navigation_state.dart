// SPDX-License-Identifier: MPL-2.0
import 'app_destination.dart';
import 'safe_route_descriptor.dart';

enum LocalholdUnlockKind { cold, warm }

final class LocalholdNavigationState {
  const LocalholdNavigationState({required this.isLocked, required this.route});

  const LocalholdNavigationState.locked()
    : isLocked = true,
      route = const LocalholdSafeRouteDescriptor.home();

  const LocalholdNavigationState.unlockedHome()
    : isLocked = false,
      route = const LocalholdSafeRouteDescriptor.home();

  final bool isLocked;
  final LocalholdSafeRouteDescriptor route;

  LocalholdDestination get destination => route.destination;
  LocalholdSafeLeaf get leaf => route.leaf;
}

abstract final class LocalholdNavigationReducer {
  static LocalholdNavigationState selectDestination(
    LocalholdNavigationState state,
    LocalholdDestination destination,
  ) {
    if (state.isLocked) return state;
    return LocalholdNavigationState(
      isLocked: false,
      route: _overview(destination),
    );
  }

  static LocalholdNavigationState openLeaf(
    LocalholdNavigationState state,
    LocalholdSafeLeaf leaf,
  ) {
    if (state.isLocked) return state;
    return LocalholdNavigationState(
      isLocked: false,
      route: LocalholdSafeRouteDescriptor(leaf: leaf),
    );
  }

  static LocalholdNavigationState lock(LocalholdNavigationState state) =>
      LocalholdNavigationState(isLocked: true, route: state.route);

  static LocalholdNavigationState unlock(
    LocalholdNavigationState state,
    LocalholdUnlockKind kind,
  ) => switch (kind) {
    LocalholdUnlockKind.cold => const LocalholdNavigationState.unlockedHome(),
    LocalholdUnlockKind.warm => LocalholdNavigationState(
      isLocked: false,
      route: _overview(state.destination),
    ),
  };

  static LocalholdSafeRouteDescriptor restoreForWarmUnlock(String? encoded) {
    final decoded = LocalholdSafeRouteCodec.decode(encoded);
    return _overview(decoded.destination);
  }

  static LocalholdSafeRouteDescriptor _overview(
    LocalholdDestination destination,
  ) => switch (destination) {
    LocalholdDestination.vault => const LocalholdSafeRouteDescriptor.home(),
    LocalholdDestination.subscriptions => const LocalholdSafeRouteDescriptor(
      leaf: LocalholdSafeLeaf.subscriptionOverview,
    ),
    LocalholdDestination.security => const LocalholdSafeRouteDescriptor(
      leaf: LocalholdSafeLeaf.securityOverview,
    ),
    LocalholdDestination.settings => const LocalholdSafeRouteDescriptor(
      leaf: LocalholdSafeLeaf.settingsOverview,
    ),
  };
}

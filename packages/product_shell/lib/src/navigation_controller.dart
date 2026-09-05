// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/foundation.dart';

import 'app_destination.dart';
import 'navigation_state.dart';
import 'safe_route_descriptor.dart';

final class LocalholdNavigationController extends ChangeNotifier {
  LocalholdNavigationController({
    LocalholdNavigationState initialState =
        const LocalholdNavigationState.unlockedHome(),
  }) : _state = initialState;

  LocalholdNavigationState _state;

  LocalholdNavigationState get state => _state;

  void selectDestination(LocalholdDestination destination) => _replace(
    LocalholdNavigationReducer.selectDestination(_state, destination),
  );

  void openLeaf(LocalholdSafeLeaf leaf) =>
      _replace(LocalholdNavigationReducer.openLeaf(_state, leaf));

  void lock() => _replace(LocalholdNavigationReducer.lock(_state));

  void unlock(LocalholdUnlockKind kind) =>
      _replace(LocalholdNavigationReducer.unlock(_state, kind));

  void _replace(LocalholdNavigationState next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }
}

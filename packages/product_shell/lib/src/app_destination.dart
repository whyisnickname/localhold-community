// SPDX-License-Identifier: MPL-2.0

enum LocalholdDestination { vault, subscriptions, security, settings }

extension LocalholdDestinationIndex on LocalholdDestination {
  int get navigationIndex => LocalholdDestination.values.indexOf(this);
}

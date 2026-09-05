// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

import 'app_destination.dart';

final class LocalholdAdaptiveShell extends StatelessWidget {
  const LocalholdAdaptiveShell({
    required this.destination,
    required this.onDestinationSelected,
    required this.content,
    this.secondaryPane,
    super.key,
  });

  final LocalholdDestination destination;
  final ValueChanged<LocalholdDestination> onDestinationSelected;
  final Widget content;
  final Widget? secondaryPane;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final windowClass = LocalholdBreakpoints.classify(constraints.maxWidth);
      return switch (windowClass) {
        LocalholdWindowClass.compact => _CompactShell(
          destination: destination,
          onDestinationSelected: onDestinationSelected,
          content: content,
        ),
        LocalholdWindowClass.medium => _RailShell(
          destination: destination,
          onDestinationSelected: onDestinationSelected,
          content: content,
        ),
        LocalholdWindowClass.expanded => _RailShell(
          destination: destination,
          onDestinationSelected: onDestinationSelected,
          content: content,
          secondaryPane: secondaryPane,
        ),
      };
    },
  );
}

final class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.destination,
    required this.onDestinationSelected,
    required this.content,
  });

  final LocalholdDestination destination;
  final ValueChanged<LocalholdDestination> onDestinationSelected;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final specs = _destinationSpecs(context);
    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        key: const ValueKey<String>('localhold-bottom-navigation'),
        selectedIndex: destination.navigationIndex,
        onDestinationSelected: (index) =>
            onDestinationSelected(LocalholdDestination.values[index]),
        destinations: <NavigationDestination>[
          for (final spec in specs)
            NavigationDestination(
              icon: Icon(spec.icon),
              selectedIcon: Icon(spec.selectedIcon),
              label: spec.label,
              tooltip: spec.label,
            ),
        ],
      ),
    );
  }
}

final class _RailShell extends StatelessWidget {
  const _RailShell({
    required this.destination,
    required this.onDestinationSelected,
    required this.content,
    this.secondaryPane,
  });

  final LocalholdDestination destination;
  final ValueChanged<LocalholdDestination> onDestinationSelected;
  final Widget content;
  final Widget? secondaryPane;

  @override
  Widget build(BuildContext context) {
    final specs = _destinationSpecs(context);
    final colors = Theme.of(context).extension<LocalholdColors>()!;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              key: const ValueKey<String>('localhold-navigation-rail'),
              selectedIndex: destination.navigationIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) =>
                  onDestinationSelected(LocalholdDestination.values[index]),
              destinations: <NavigationRailDestination>[
                for (final spec in specs)
                  NavigationRailDestination(
                    icon: Icon(spec.icon),
                    selectedIcon: Icon(spec.selectedIcon),
                    label: Text(spec.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: colors.border),
            Expanded(child: content),
            if (secondaryPane case final pane?) ...[
              VerticalDivider(width: 1, color: colors.border),
              SizedBox(
                key: const ValueKey<String>('localhold-secondary-pane'),
                width: 320,
                child: pane,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _DestinationSpec {
  const _DestinationSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

List<_DestinationSpec> _destinationSpecs(BuildContext context) {
  final strings = LocalholdLocalizations.of(context);
  return <_DestinationSpec>[
    _DestinationSpec(
      label: strings.navVault,
      icon: Icons.lock_outline,
      selectedIcon: Icons.lock,
    ),
    _DestinationSpec(
      label: strings.navSubscriptions,
      icon: Icons.event_repeat_outlined,
      selectedIcon: Icons.event_repeat,
    ),
    _DestinationSpec(
      label: strings.navSecurity,
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield,
    ),
    _DestinationSpec(
      label: strings.navSettings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];
}

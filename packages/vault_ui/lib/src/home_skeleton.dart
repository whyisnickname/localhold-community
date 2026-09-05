// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

enum HomeSafetyStatus { ready, recoveryMissing }

@immutable
final class HomeActionItem {
  const HomeActionItem({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

@immutable
final class HomeSkeletonModel {
  const HomeSkeletonModel({
    required this.safetyStatus,
    this.quickFilters = const [],
    this.builtInTypes = const [],
    this.recentSafeItems = const [],
  });

  final HomeSafetyStatus safetyStatus;
  final List<HomeActionItem> quickFilters;
  final List<HomeActionItem> builtInTypes;

  /// Values must already be approved safe preview labels. D03 never derives
  /// previews from record fields.
  final List<HomeActionItem> recentSafeItems;
}

final class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({
    required this.model,
    required this.onSafetyAction,
    required this.onQuickFilter,
    required this.onType,
    required this.onRecent,
    required this.onChooseVault,
    super.key,
  });

  final HomeSkeletonModel model;
  final VoidCallback onSafetyAction;
  final ValueChanged<String> onQuickFilter;
  final ValueChanged<String> onType;
  final ValueChanged<String> onRecent;
  final VoidCallback onChooseVault;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(strings.navVault),
          actions: [
            IconButton(
              onPressed: onChooseVault,
              tooltip: strings.unlockChooseVault,
              icon: const Icon(Icons.swap_horiz),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(LocalholdSpacing.md),
          sliver: SliverList.list(
            children: [
              _SafetyCard(status: model.safetyStatus, onTap: onSafetyAction),
              if (model.quickFilters.isNotEmpty) ...[
                const SizedBox(height: LocalholdSpacing.lg),
                _SectionTitle(strings.homeQuickFilters),
                Wrap(
                  spacing: LocalholdSpacing.sm,
                  runSpacing: LocalholdSpacing.sm,
                  children: [
                    for (final item in model.quickFilters)
                      ActionChip(
                        avatar: Icon(item.icon),
                        label: Text(item.label),
                        onPressed: () => onQuickFilter(item.id),
                      ),
                  ],
                ),
              ],
              if (model.builtInTypes.isNotEmpty) ...[
                const SizedBox(height: LocalholdSpacing.lg),
                _SectionTitle(strings.homeTypes),
                _AdaptiveActionGrid(items: model.builtInTypes, onTap: onType),
              ],
              const SizedBox(height: LocalholdSpacing.lg),
              _SectionTitle(strings.homeRecents),
              if (model.recentSafeItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: LocalholdSpacing.lg,
                  ),
                  child: Text(strings.homeNoRecents),
                )
              else
                for (final item in model.recentSafeItems)
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: () => onRecent(item.id),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.status, required this.onTap});

  final HomeSafetyStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final ready = status == HomeSafetyStatus.ready;
    return Card(
      child: ListTile(
        leading: Icon(
          ready ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
        ),
        title: Text(strings.homeSafetyTitle),
        subtitle: Text(
          ready ? strings.homeSafetyReady : strings.homeSafetyRecoveryMissing,
        ),
        trailing: ready ? null : const Icon(Icons.chevron_right),
        onTap: ready ? null : onTap,
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LocalholdSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

final class _AdaptiveActionGrid extends StatelessWidget {
  const _AdaptiveActionGrid({required this.items, required this.onTap});

  final List<HomeActionItem> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 96,
          crossAxisSpacing: LocalholdSpacing.sm,
          mainAxisSpacing: LocalholdSpacing.sm,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(LocalholdRadii.section),
              onTap: () => onTap(item.id),
              child: Padding(
                padding: const EdgeInsets.all(LocalholdSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(item.icon), Text(item.label)],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

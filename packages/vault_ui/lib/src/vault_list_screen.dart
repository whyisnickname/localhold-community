// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'template_presentation.dart';
import 'vault_list_controller.dart';

enum VaultListBulkIntent {
  move,
  tags,
  favorite,
  archive,
  trash,
  portabilityExport,
}

final class VaultListScreen extends StatefulWidget {
  const VaultListScreen({
    required this.controller,
    required this.onOpenRecord,
    required this.onBulkIntent,
    super.key,
  });

  final VaultListController controller;
  final ValueChanged<RecordId> onOpenRecord;
  final ValueChanged<VaultListBulkIntent> onBulkIntent;

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

final class _VaultListScreenState extends State<VaultListScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.controller.state.query);
    widget.controller.addListener(_syncQuery);
  }

  @override
  void didUpdateWidget(covariant VaultListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncQuery);
    widget.controller.addListener(_syncQuery);
    _syncQuery();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncQuery);
    _search.dispose();
    super.dispose();
  }

  void _syncQuery() {
    final value = widget.controller.state.query;
    if (_search.text == value) return;
    _search.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final strings = LocalholdLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(strings.vaultAllRecords),
          actions: [
            IconButton(
              tooltip: '${strings.vaultFolder} / ${strings.vaultTags}',
              onPressed: _showOrganizationFilters,
              icon: const Icon(Icons.filter_list),
            ),
            PopupMenuButton<VaultRecordSort>(
              tooltip: strings.vaultSortNewest,
              onSelected: widget.controller.setSort,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: VaultRecordSort.updatedNewest,
                  child: Text(strings.vaultSortNewest),
                ),
                PopupMenuItem(
                  value: VaultRecordSort.updatedOldest,
                  child: Text(strings.vaultSortOldest),
                ),
                PopupMenuItem(
                  value: VaultRecordSort.safeTitleAscending,
                  child: Text(strings.vaultSortTitleAsc),
                ),
                PopupMenuItem(
                  value: VaultRecordSort.safeTitleDescending,
                  child: Text(strings.vaultSortTitleDesc),
                ),
              ],
              icon: const Icon(Icons.sort),
            ),
            PopupMenuButton<VaultListLayout>(
              tooltip: _layoutLabel(strings, state.preferences.layout),
              onSelected: widget.controller.setLayout,
              itemBuilder: (context) => VaultListLayout.values
                  .map(
                    (layout) => PopupMenuItem(
                      value: layout,
                      child: Text(_layoutLabel(strings, layout)),
                    ),
                  )
                  .toList(growable: false),
              icon: const Icon(Icons.view_agenda_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LocalholdSpacing.md,
                  LocalholdSpacing.sm,
                  LocalholdSpacing.md,
                  0,
                ),
                child: SearchBar(
                  controller: _search,
                  hintText: strings.vaultSearch,
                  leading: const Icon(Icons.search),
                  trailing: [
                    IconButton(
                      tooltip: state.protectedSearch
                          ? strings.vaultSearchProtectedActive
                          : strings.vaultSearchProtected,
                      onPressed: state.protectedSearch
                          ? () => widget.controller.disableProtectedSearch()
                          : _requestProtectedSearch,
                      icon: Icon(
                        state.protectedSearch
                            ? Icons.shield
                            : Icons.shield_outlined,
                      ),
                    ),
                  ],
                  onChanged: widget.controller.setQuery,
                ),
              ),
              if (state.protectedSearch)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LocalholdSpacing.md,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: InputChip(
                      avatar: const Icon(Icons.verified_user_outlined),
                      label: Text(strings.vaultSearchProtectedActive),
                      onDeleted: () =>
                          widget.controller.disableProtectedSearch(),
                    ),
                  ),
                ),
              _FilterStrip(state: state, controller: widget.controller),
              if (state.filter.lifecycle == RecordLifecycle.trashed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LocalholdSpacing.md,
                    0,
                    LocalholdSpacing.md,
                    LocalholdSpacing.sm,
                  ),
                  child: Text(strings.vaultTrashRetention),
                ),
              if (state.issue case final issue?)
                _IssueBanner(issue: issue, onRetry: widget.controller.load),
              Expanded(child: _buildBody(state)),
            ],
          ),
        ),
        bottomNavigationBar: state.selectedIds.isEmpty
            ? null
            : _BulkBar(
                count: state.selectedIds.length,
                onClear: widget.controller.clearSelection,
                onIntent: widget.onBulkIntent,
              ),
      );
    },
  );

  Widget _buildBody(VaultListState state) {
    final strings = LocalholdLocalizations.of(context);
    return switch (state.status) {
      VaultListStatus.initial || VaultListStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      VaultListStatus.recoverableFailure || VaultListStatus.readOnly => Center(
        child: Padding(
          padding: const EdgeInsets.all(LocalholdSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.vaultLoadFailed, textAlign: TextAlign.center),
              const SizedBox(height: LocalholdSpacing.md),
              FilledButton(
                onPressed: widget.controller.load,
                child: Text(strings.vaultTryAgain),
              ),
            ],
          ),
        ),
      ),
      VaultListStatus.locked => const SizedBox.shrink(),
      VaultListStatus.empty => Center(
        child: Padding(
          padding: const EdgeInsets.all(LocalholdSpacing.lg),
          child: Text(strings.vaultNoRecords, textAlign: TextAlign.center),
        ),
      ),
      VaultListStatus.ready => _RecordCollection(
        items: state.items,
        layout: state.preferences.layout,
        selected: state.selectedIds,
        onOpen: widget.onOpenRecord,
        onSelect: widget.controller.toggleSelection,
        onPinned: (id) =>
            widget.controller.togglePinned(id, now: DateTime.now()),
        onRestore: (id) => widget.controller.restore(id, now: DateTime.now()),
      ),
    };
  }

  Future<void> _requestProtectedSearch() async {
    final strings = LocalholdLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.vaultSearchProtected),
        content: Text(strings.vaultSearchProtectedHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.commonConfirm),
          ),
        ],
      ),
    );
    if (accepted == true) await widget.controller.enableProtectedSearch();
  }

  Future<void> _showOrganizationFilters() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final strings = LocalholdLocalizations.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LocalholdSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.vaultFolder,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: LocalholdSpacing.sm),
                Wrap(
                  spacing: LocalholdSpacing.sm,
                  runSpacing: LocalholdSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: Text(strings.vaultAnyFolder),
                      selected: state.filter.folderId == null,
                      onSelected: (_) =>
                          widget.controller.setFolderFilter(null),
                    ),
                    for (final folder in state.folders)
                      ChoiceChip(
                        label: Text(folder.name),
                        selected: state.filter.folderId == folder.id.value,
                        onSelected: (_) =>
                            widget.controller.setFolderFilter(folder.id),
                      ),
                  ],
                ),
                const SizedBox(height: LocalholdSpacing.lg),
                Text(
                  strings.vaultTags,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: LocalholdSpacing.sm),
                Wrap(
                  spacing: LocalholdSpacing.sm,
                  runSpacing: LocalholdSpacing.sm,
                  children: [
                    for (final tag in state.tags)
                      FilterChip(
                        label: Text(tag.name),
                        selected: state.filter.requiredTagIds.contains(
                          tag.id.value,
                        ),
                        onSelected: (_) =>
                            widget.controller.toggleTagFilter(tag.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

final class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.state, required this.controller});

  final VaultListState state;
  final VaultListController controller;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(LocalholdSpacing.md),
      child: Row(
        children: [
          _chip(
            strings.vaultFilterAll,
            state.filter.lifecycle == RecordLifecycle.active &&
                !state.filter.favoriteOnly &&
                !state.filter.pinnedOnly,
            const VaultSearchFilter(lifecycle: RecordLifecycle.active),
          ),
          _chip(
            strings.vaultFilterFavorites,
            state.filter.favoriteOnly,
            const VaultSearchFilter(
              lifecycle: RecordLifecycle.active,
              favoriteOnly: true,
            ),
          ),
          _chip(
            strings.vaultFilterPinned,
            state.filter.pinnedOnly,
            const VaultSearchFilter(
              lifecycle: RecordLifecycle.active,
              pinnedOnly: true,
            ),
          ),
          _chip(
            strings.vaultFilterArchive,
            state.filter.lifecycle == RecordLifecycle.archived,
            const VaultSearchFilter(lifecycle: RecordLifecycle.archived),
          ),
          _chip(
            strings.vaultFilterTrash,
            state.filter.lifecycle == RecordLifecycle.trashed,
            const VaultSearchFilter(lifecycle: RecordLifecycle.trashed),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VaultSearchFilter filter) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(end: LocalholdSpacing.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => controller.setFilter(filter),
        ),
      );
}

final class _RecordCollection extends StatelessWidget {
  const _RecordCollection({
    required this.items,
    required this.layout,
    required this.selected,
    required this.onOpen,
    required this.onSelect,
    required this.onPinned,
    required this.onRestore,
  });

  final List<SafeRecordProjection> items;
  final VaultListLayout layout;
  final Set<RecordId> selected;
  final ValueChanged<RecordId> onOpen;
  final ValueChanged<RecordId> onSelect;
  final ValueChanged<RecordId> onPinned;
  final ValueChanged<RecordId> onRestore;

  @override
  Widget build(BuildContext context) {
    if (layout == VaultListLayout.grid) {
      return LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          padding: const EdgeInsets.all(LocalholdSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 840
                ? 4
                : constraints.maxWidth >= 600
                ? 2
                : 1,
            mainAxisExtent: 150,
            crossAxisSpacing: LocalholdSpacing.sm,
            mainAxisSpacing: LocalholdSpacing.sm,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _RecordTile(
            item: items[index],
            selected: selected.contains(items[index].id),
            grid: true,
            onOpen: onOpen,
            onSelect: onSelect,
            onPinned: onPinned,
            onRestore: onRestore,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => _RecordTile(
        item: items[index],
        selected: selected.contains(items[index].id),
        grid: false,
        comfortable: layout == VaultListLayout.comfortable,
        onOpen: onOpen,
        onSelect: onSelect,
        onPinned: onPinned,
        onRestore: onRestore,
      ),
    );
  }
}

final class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.item,
    required this.selected,
    required this.grid,
    required this.onOpen,
    required this.onSelect,
    required this.onPinned,
    required this.onRestore,
    this.comfortable = false,
  });

  final SafeRecordProjection item;
  final bool selected;
  final bool grid;
  final bool comfortable;
  final ValueChanged<RecordId> onOpen;
  final ValueChanged<RecordId> onSelect;
  final ValueChanged<RecordId> onPinned;
  final ValueChanged<RecordId> onRestore;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final type = localizedTemplateName(strings, item.typeId);
    final subtitle = [
      type,
      if (item.secondary case final value?) value,
      if (item.folderName case final value?) value,
      if (item.tagNames.isNotEmpty) item.tagNames.join(', '),
    ].join(' · ');
    final tile = ListTile(
      selected: selected,
      contentPadding: EdgeInsets.symmetric(
        horizontal: LocalholdSpacing.md,
        vertical: comfortable ? LocalholdSpacing.sm : 0,
      ),
      leading: selected
          ? const Icon(Icons.check_circle)
          : const Icon(Icons.description_outlined),
      title: Text(
        item.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: 0,
        children: [
          if (item.favorite)
            Icon(Icons.star, semanticLabel: strings.vaultFavorite),
          if (item.lifecycle == RecordLifecycle.active)
            IconButton(
              tooltip: strings.vaultPinned,
              onPressed: () => onPinned(item.id),
              icon: Icon(
                item.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            )
          else
            IconButton(
              tooltip: strings.vaultRestore,
              onPressed: () => onRestore(item.id),
              icon: const Icon(Icons.restore),
            ),
        ],
      ),
      onTap: selected ? () => onSelect(item.id) : () => onOpen(item.id),
      onLongPress: () => onSelect(item.id),
    );
    return grid ? Card(clipBehavior: Clip.antiAlias, child: tile) : tile;
  }
}

final class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.issue, required this.onRetry});

  final VaultListIssue issue;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final message = switch (issue) {
      VaultListIssue.authorizationDenied =>
        strings.vaultSearchAuthorizationDenied,
      VaultListIssue.storageFailure => strings.vaultStorageActionFailed,
      VaultListIssue.exportFailure => strings.vaultExportFailed,
    };
    return MaterialBanner(
      content: Text(message),
      actions: issue == VaultListIssue.storageFailure
          ? [TextButton(onPressed: onRetry, child: Text(strings.vaultTryAgain))]
          : const [SizedBox.shrink()],
    );
  }
}

final class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onClear,
    required this.onIntent,
  });

  final int count;
  final VoidCallback onClear;
  final ValueChanged<VaultListBulkIntent> onIntent;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final actions = <(VaultListBulkIntent, IconData, String)>[
      (
        VaultListBulkIntent.move,
        Icons.drive_file_move_outline,
        strings.vaultBulkMove,
      ),
      (VaultListBulkIntent.tags, Icons.label_outline, strings.vaultBulkTags),
      (
        VaultListBulkIntent.favorite,
        Icons.star_outline,
        strings.vaultBulkFavorite,
      ),
      (
        VaultListBulkIntent.archive,
        Icons.archive_outlined,
        strings.vaultBulkArchive,
      ),
      (VaultListBulkIntent.trash, Icons.delete_outline, strings.vaultBulkTrash),
      (
        VaultListBulkIntent.portabilityExport,
        Icons.ios_share,
        strings.vaultBulkExport,
      ),
    ];
    return SafeArea(
      child: Material(
        elevation: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(strings.vaultSelected(count)),
              trailing: IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                LocalholdSpacing.sm,
                0,
                LocalholdSpacing.sm,
                LocalholdSpacing.sm,
              ),
              child: Row(
                children: [
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: LocalholdSpacing.sm,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () => onIntent(action.$1),
                        icon: Icon(action.$2),
                        label: Text(action.$3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _layoutLabel(LocalholdLocalizations strings, VaultListLayout layout) =>
    switch (layout) {
      VaultListLayout.compact => strings.vaultLayoutCompact,
      VaultListLayout.comfortable => strings.vaultLayoutComfortable,
      VaultListLayout.grid => strings.vaultLayoutGrid,
    };

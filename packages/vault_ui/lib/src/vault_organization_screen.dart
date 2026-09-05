// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'vault_organization_controller.dart';

final class VaultOrganizationScreen extends StatelessWidget {
  const VaultOrganizationScreen({
    required this.controller,
    required this.onMoveFolder,
    required this.onMergeTag,
    super.key,
  });

  final VaultOrganizationController controller;
  final ValueChanged<FolderId> onMoveFolder;
  final ValueChanged<TagId> onMergeTag;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.state;
      final strings = LocalholdLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(strings.organizationTitle)),
        body: SafeArea(
          child: switch (state.status) {
            VaultOrganizationStatus.initial ||
            VaultOrganizationStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            VaultOrganizationStatus.locked => const SizedBox.shrink(),
            VaultOrganizationStatus.readOnly ||
            VaultOrganizationStatus.recoverableFailure => _OrganizationBody(
              state: state,
              controller: controller,
              onMoveFolder: onMoveFolder,
              onMergeTag: onMergeTag,
              failure: true,
            ),
            VaultOrganizationStatus.empty ||
            VaultOrganizationStatus.ready => _OrganizationBody(
              state: state,
              controller: controller,
              onMoveFolder: onMoveFolder,
              onMergeTag: onMergeTag,
              failure: false,
            ),
          },
        ),
      );
    },
  );
}

final class _OrganizationBody extends StatelessWidget {
  const _OrganizationBody({
    required this.state,
    required this.controller,
    required this.onMoveFolder,
    required this.onMergeTag,
    required this.failure,
  });

  final VaultOrganizationState state;
  final VaultOrganizationController controller;
  final ValueChanged<FolderId> onMoveFolder;
  final ValueChanged<TagId> onMergeTag;
  final bool failure;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(LocalholdSpacing.md),
      children: [
        if (failure)
          MaterialBanner(
            content: Text(strings.organizationSaveFailed),
            actions: [
              TextButton(
                onPressed: controller.load,
                child: Text(strings.vaultTryAgain),
              ),
            ],
          ),
        _SectionHeader(
          title: strings.organizationFolders,
          action: strings.organizationAddFolder,
          onPressed: () => _requestName(
            context,
            title: strings.organizationAddFolder,
            onSubmit: controller.addFolder,
          ),
        ),
        if (state.folders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LocalholdSpacing.md),
            child: Text(strings.organizationEmpty),
          )
        else
          for (final folder in state.folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              subtitle: Text(
                controller
                    .breadcrumb(folder.id)
                    .map((value) => value.name)
                    .join(' / '),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'rename') {
                    await _requestName(
                      context,
                      title: strings.organizationRename,
                      initial: folder.name,
                      onSubmit: (value) =>
                          controller.renameFolder(folder.id, value),
                    );
                  } else if (action == 'move') {
                    onMoveFolder(folder.id);
                  } else if (action == 'delete') {
                    await _confirmDelete(
                      context,
                      title: strings.organizationDelete,
                      body: strings.organizationDeleteFolderHint,
                      onDelete: () => controller.deleteFolder(
                        folder.id,
                        now: DateTime.now(),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(strings.organizationRename),
                  ),
                  PopupMenuItem(
                    value: 'move',
                    child: Text(strings.organizationMove),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(strings.organizationDelete),
                  ),
                ],
              ),
            ),
        const Divider(height: LocalholdSpacing.xl),
        _SectionHeader(
          title: strings.organizationTags,
          action: strings.organizationAddTag,
          onPressed: () => _requestName(
            context,
            title: strings.organizationAddTag,
            onSubmit: controller.addTag,
          ),
        ),
        for (final tag in state.tags)
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(tag.name),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'rename') {
                  await _requestName(
                    context,
                    title: strings.organizationRename,
                    initial: tag.name,
                    onSubmit: (value) => controller.renameTag(tag.id, value),
                  );
                } else if (action == 'merge') {
                  onMergeTag(tag.id);
                } else if (action == 'delete') {
                  await _confirmDelete(
                    context,
                    title: strings.organizationDelete,
                    body: strings.organizationDeleteTagHint,
                    onDelete: () =>
                        controller.deleteTag(tag.id, now: DateTime.now()),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text(strings.organizationRename),
                ),
                PopupMenuItem(
                  value: 'merge',
                  child: Text(strings.organizationMerge),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(strings.organizationDelete),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: LocalholdSpacing.xs),
      TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(action),
      ),
    ],
  );
}

Future<void> _requestName(
  BuildContext context, {
  required String title,
  required Future<void> Function(String value) onSubmit,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final strings = LocalholdLocalizations.of(context);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 256,
        decoration: InputDecoration(labelText: strings.organizationName),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(strings.commonConfirm),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value != null && value.trim().isNotEmpty) await onSubmit(value.trim());
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required String body,
  required Future<void> Function() onDelete,
}) async {
  final strings = LocalholdLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(strings.organizationDelete),
        ),
      ],
    ),
  );
  if (accepted == true) await onDelete();
}

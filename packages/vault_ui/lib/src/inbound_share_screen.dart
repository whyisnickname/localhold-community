// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'inbound_share_controller.dart';

final class InboundShareScreen extends StatefulWidget {
  const InboundShareScreen({
    required this.controller,
    this.onImported,
    super.key,
  });

  final InboundShareController controller;
  final ValueChanged<DraftId>? onImported;

  @override
  State<InboundShareScreen> createState() => _InboundShareScreenState();
}

final class _InboundShareScreenState extends State<InboundShareScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.controller.load();
  }

  @override
  void didUpdateWidget(covariant InboundShareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onChanged);
    widget.controller.addListener(_onChanged);
    widget.controller.load();
  }

  void _onChanged() {
    final state = widget.controller.state;
    final draftId = state.importedDraftId;
    if (state.status == InboundShareViewStatus.imported && draftId != null) {
      widget.onImported?.call(draftId);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final strings = LocalholdLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(strings.shareInboxTitle)),
        body: SafeArea(
          child: switch (state.status) {
            InboundShareViewStatus.locked => const SizedBox.shrink(),
            InboundShareViewStatus.initial ||
            InboundShareViewStatus.loading ||
            InboundShareViewStatus.importing => const Center(
              child: CircularProgressIndicator(),
            ),
            InboundShareViewStatus.empty => _Message(
              icon: Icons.inbox_outlined,
              text: strings.shareInboxEmpty,
            ),
            InboundShareViewStatus.recoverableFailure => _Message(
              icon: Icons.error_outline,
              text: strings.shareImportFailed,
              action: FilledButton(
                onPressed: widget.controller.load,
                child: Text(strings.vaultTryAgain),
              ),
            ),
            _ => ListView.separated(
              padding: const EdgeInsets.all(LocalholdSpacing.md),
              itemCount: state.descriptors.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: LocalholdSpacing.sm),
              itemBuilder: (context, index) => _ShareCard(
                descriptor: state.descriptors[index],
                controller: widget.controller,
              ),
            ),
          },
        ),
      );
    },
  );
}

final class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.descriptor, required this.controller});

  final InboundShareDescriptor descriptor;
  final InboundShareController controller;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final kind = switch (descriptor.kind) {
      InboundShareKind.text => strings.shareKindText,
      InboundShareKind.url => strings.shareKindUrl,
      InboundShareKind.file => strings.shareKindFile,
      InboundShareKind.image => strings.shareKindImage,
    };
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(LocalholdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (descriptor.kind) {
                InboundShareKind.text => Icons.text_snippet_outlined,
                InboundShareKind.url => Icons.link_outlined,
                InboundShareKind.file => Icons.insert_drive_file_outlined,
                InboundShareKind.image => Icons.image_outlined,
              }),
              title: Text(kind),
              subtitle: Text(strings.shareBytes(descriptor.byteLength)),
            ),
            Text(strings.shareProtectedHint),
            const SizedBox(height: LocalholdSpacing.sm),
            FilledButton(
              onPressed: () => controller.import(descriptor.id),
              child: Text(strings.shareImport),
            ),
            TextButton(
              onPressed: () => controller.discard(descriptor.id),
              child: Text(strings.shareDiscard),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(LocalholdSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: LocalholdSpacing.md),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: LocalholdSpacing.md),
            action!,
          ],
        ],
      ),
    ),
  );
}

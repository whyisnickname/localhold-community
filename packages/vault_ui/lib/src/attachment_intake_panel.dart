// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'attachment_queue_controller.dart';

final class AttachmentIntakePanel extends StatelessWidget {
  const AttachmentIntakePanel({required this.controller, super.key});

  final AttachmentQueueController controller;

  @override
  Widget build(BuildContext context) => Material(
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final strings = LocalholdLocalizations.of(context);
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(strings.attachmentFile),
              onTap: () => controller.enqueue(AttachmentSourceKind.file),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(strings.attachmentPhoto),
              onTap: () => controller.enqueue(AttachmentSourceKind.photoPicker),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(strings.attachmentCamera),
              onTap: () => controller.enqueue(AttachmentSourceKind.camera),
            ),
            for (final item in controller.items)
              _QueueTile(
                item: item,
                onCancel: () => controller.cancel(item.id),
              ),
          ],
        );
      },
    ),
  );
}

final class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.item, required this.onCancel});

  final AttachmentQueueItem item;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final message = switch (item.status) {
      AttachmentQueueStatus.queued ||
      AttachmentQueueStatus.importing => strings.attachmentImporting,
      AttachmentQueueStatus.imported => item.result?.displayName ?? '',
      AttachmentQueueStatus.cancelled => strings.commonCancel,
      AttachmentQueueStatus.permissionDenied =>
        strings.attachmentPermissionDenied,
      AttachmentQueueStatus.unavailable => strings.attachmentUnavailable,
      AttachmentQueueStatus.failed => strings.attachmentImportFailed,
    };
    final active =
        item.status == AttachmentQueueStatus.queued ||
        item.status == AttachmentQueueStatus.importing;
    return ListTile(
      leading: active
          ? CircularProgressIndicator(
              value: item.progress == 0 ? null : item.progress,
            )
          : Icon(
              item.status == AttachmentQueueStatus.imported
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
            ),
      title: Text(message),
      trailing: active
          ? IconButton(
              onPressed: onCancel,
              tooltip: strings.attachmentCancel,
              icon: const Icon(Icons.close),
            )
          : null,
    );
  }
}

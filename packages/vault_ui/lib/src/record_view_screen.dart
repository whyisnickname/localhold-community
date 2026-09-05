// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'record_view_controller.dart';
import 'template_presentation.dart';
import 'template_field_localizations.dart';

final class RecordViewScreen extends StatefulWidget {
  const RecordViewScreen({
    required this.controller,
    required this.onEdit,
    required this.onCopy,
    required this.onPermanentDelete,
    this.onOpen,
    super.key,
  });

  final RecordViewController controller;
  final VoidCallback onEdit;
  final ValueChanged<VaultField> onCopy;
  final ValueChanged<VaultField>? onOpen;
  final VoidCallback onPermanentDelete;

  @override
  State<RecordViewScreen> createState() => _RecordViewScreenState();
}

final class _RecordViewScreenState extends State<RecordViewScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.clearReveals(notify: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.controller.clearReveals();
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final controller = widget.controller;
    final definitions = {
      for (final definition in controller.template.fields)
        definition.stableId: definition,
    };
    final visible = controller.record.fields
        .where((field) => field.hasUserValue)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          EditorDraftSnapshot.fromRecord(controller.record)
                  .safeDisplayValue(controller.template) ??
              localizedTemplateName(strings, controller.template.stableId),
        ),
        actions: [
          IconButton(
            onPressed: widget.onEdit,
            tooltip: strings.recordViewEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(LocalholdSpacing.md),
          children: [
            Text(
              localizedTemplateName(strings, controller.template.stableId),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: LocalholdSpacing.md),
            if (visible.isEmpty)
              Text(strings.recordViewEmpty)
            else
              for (final field in visible)
                _RecordFieldTile(
                  field: field,
                  label: localizedTemplateFieldLabel(
                    strings,
                    controller.template.stableId,
                    field,
                  ),
                  protected:
                      definitions[field.definitionId]?.protected == true ||
                      field.kind == VaultFieldKind.secret ||
                      field.kind == VaultFieldKind.totp,
                  revealed: controller.isRevealed(field.id),
                  onReveal: () => controller.toggleReveal(field.id),
                  onCopy: () => widget.onCopy(field),
                  onOpen: _canOpen(field.kind) && widget.onOpen != null
                      ? () => widget.onOpen!(field)
                      : null,
                ),
            const SizedBox(height: LocalholdSpacing.xl * 2),
            const Divider(),
            const SizedBox(height: LocalholdSpacing.md),
            OutlinedButton.icon(
              onPressed: widget.onPermanentDelete,
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(strings.recordViewDelete),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canOpen(VaultFieldKind kind) =>
      kind == VaultFieldKind.url ||
      kind == VaultFieldKind.email ||
      kind == VaultFieldKind.phone ||
      kind == VaultFieldKind.attachment;
}

final class _RecordFieldTile extends StatelessWidget {
  const _RecordFieldTile({
    required this.field,
    required this.label,
    required this.protected,
    required this.revealed,
    required this.onReveal,
    required this.onCopy,
    this.onOpen,
  });

  final VaultField field;
  final String label;
  final bool protected;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final hidden = protected && !revealed;
    final display = hidden ? '••••••••' : _displayValue(field);
    final content = ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(display),
      trailing: Wrap(
        children: [
          if (protected)
            IconButton(
              onPressed: onReveal,
              tooltip: revealed
                  ? strings.recordViewHide
                  : strings.recordViewReveal,
              icon: Icon(
                revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          IconButton(
            onPressed: hidden ? null : onCopy,
            tooltip: strings.recordViewCopy,
            icon: const Icon(Icons.copy_outlined),
          ),
          if (onOpen != null)
            IconButton(
              onPressed: onOpen,
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
    );
    if (!hidden) return content;
    return Semantics(
      label: '$label, ${strings.valueHidden}',
      child: ExcludeSemantics(child: content),
    );
  }

  String _displayValue(VaultField field) {
    final value = field.value;
    if (field.kind == VaultFieldKind.totp && value is Map) {
      return [
        value['issuer'],
        value['account'],
      ].whereType<String>().where((item) => item.isNotEmpty).join(' — ');
    }
    if (field.kind == VaultFieldKind.attachment && value is Map) {
      return value['displayName']?.toString() ?? '';
    }
    if (value is bool) return value ? '✓' : '—';
    if (value is Iterable) return value.join(', ');
    return value?.toString() ?? '';
  }
}

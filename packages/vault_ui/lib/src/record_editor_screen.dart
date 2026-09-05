// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'record_editor_controller.dart';
import 'template_field_localizations.dart';

final class RecordEditorScreen extends StatelessWidget {
  const RecordEditorScreen({
    required this.controller,
    required this.onSaved,
    this.onAddTotp,
    this.onAddAttachment,
    this.onAddCustomField,
    this.onEditTotp,
    this.onEditAttachment,
    super.key,
  });

  final RecordEditorController controller;
  final ValueChanged<RecordMutationResult> onSaved;
  final VoidCallback? onAddTotp;
  final VoidCallback? onAddAttachment;
  final VoidCallback? onAddCustomField;
  final ValueChanged<VaultField>? onEditTotp;
  final ValueChanged<VaultField>? onEditAttachment;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop: !controller.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showBackChoices(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            controller.isEditingExisting
                ? LocalholdLocalizations.of(context).editorEditTitle
                : LocalholdLocalizations.of(context).editorCreateTitle,
          ),
          actions: [
            IconButton(
              onPressed: controller.isCommitting
                  ? null
                  : () => _commit(context),
              tooltip: LocalholdLocalizations.of(context).editorSaveRecord,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: _EditorBody(
          controller: controller,
          onRemove: (field) => _removeField(context, field),
          onCommit: () => _commit(context),
          onAddTotp: onAddTotp,
          onAddAttachment: onAddAttachment,
          onAddCustomField: onAddCustomField,
          onEditTotp: onEditTotp,
          onEditAttachment: onEditAttachment,
        ),
      ),
    ),
  );

  Future<void> _commit(BuildContext context) async {
    if (!controller.snapshot.hasUserValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalholdLocalizations.of(context).editorOneValueRequired,
          ),
        ),
      );
      return;
    }
    final result = await controller.commit();
    if (context.mounted && result != null) onSaved(result);
  }

  Future<void> _removeField(BuildContext context, VaultField field) async {
    final strings = LocalholdLocalizations.of(context);
    final plan = controller.planRemoval(field.id);
    if (plan.requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.editorDeleteFieldTitle),
          content: Text(strings.editorDeleteFieldBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.editorRemoveField),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    controller.applyRemoval(plan);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.editorRemoveField),
        action: SnackBarAction(
          label: strings.editorUndo,
          onPressed: controller.undoLastRemoval,
        ),
      ),
    );
  }

  Future<void> _showBackChoices(BuildContext context) async {
    final strings = LocalholdLocalizations.of(context);
    final choice = await showDialog<_BackChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(strings.editorBackTitle),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LocalholdSpacing.lg,
            ),
            child: Text(strings.editorBackBody),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _BackChoice.saveRecord),
            child: Text(strings.editorSaveRecord),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _BackChoice.saveDraft),
            child: Text(strings.editorSaveDraft),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, _BackChoice.continueEditing),
            child: Text(strings.editorContinueEditing),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _BackChoice.deleteDraft),
            child: Text(
              strings.editorDeleteDraft,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case _BackChoice.saveRecord:
        await _commit(context);
      case _BackChoice.saveDraft:
        if (await controller.saveDraftNow() && context.mounted) {
          Navigator.pop(context);
        }
      case _BackChoice.deleteDraft:
        if (await controller.discard() && context.mounted) {
          Navigator.pop(context);
        }
      case _BackChoice.continueEditing || null:
        break;
    }
  }
}

enum _BackChoice { saveRecord, saveDraft, continueEditing, deleteDraft }

final class _EditorBody extends StatelessWidget {
  const _EditorBody({
    required this.controller,
    required this.onRemove,
    required this.onCommit,
    this.onAddTotp,
    this.onAddAttachment,
    this.onAddCustomField,
    this.onEditTotp,
    this.onEditAttachment,
  });

  final RecordEditorController controller;
  final ValueChanged<VaultField> onRemove;
  final VoidCallback onCommit;
  final VoidCallback? onAddTotp;
  final VoidCallback? onAddAttachment;
  final VoidCallback? onAddCustomField;
  final ValueChanged<VaultField>? onEditTotp;
  final ValueChanged<VaultField>? onEditAttachment;

  @override
  Widget build(BuildContext context) {
    final definitions = {
      for (final definition in controller.template.fields)
        definition.stableId: definition,
    };
    final primary = <VaultField>[];
    final advanced = <VaultField>[];
    for (final field in controller.snapshot.fields) {
      final section = definitions[field.definitionId]?.section;
      (section == FieldSection.advanced ? advanced : primary).add(field);
    }
    return ListView(
      padding: const EdgeInsets.all(LocalholdSpacing.md),
      children: [
        _PersistenceStatus(status: controller.persistenceStatus),
        for (final field in primary)
          _EditorField(
            key: ValueKey(field.id.value),
            field: field,
            label: localizedTemplateFieldLabel(
              LocalholdLocalizations.of(context),
              controller.template.stableId,
              field,
            ),
            warningCode: definitions[field.definitionId]?.warningCode,
            onChanged: (value) => controller.updateField(field.id, value),
            onRemove: () => onRemove(field),
            onStructuredEdit: field.kind == VaultFieldKind.totp
                ? (onEditTotp == null ? null : () => onEditTotp!(field))
                : field.kind == VaultFieldKind.attachment
                ? (onEditAttachment == null
                      ? null
                      : () => onEditAttachment!(field))
                : null,
          ),
        if (advanced.isNotEmpty)
          ExpansionTile(
            initiallyExpanded: advanced.any((field) => field.hasUserValue),
            title: Text(LocalholdLocalizations.of(context).editorAdvanced),
            children: [
              for (final field in advanced)
                _EditorField(
                  key: ValueKey(field.id.value),
                  field: field,
                  label: localizedTemplateFieldLabel(
                    LocalholdLocalizations.of(context),
                    controller.template.stableId,
                    field,
                  ),
                  warningCode: definitions[field.definitionId]?.warningCode,
                  onChanged: (value) => controller.updateField(field.id, value),
                  onRemove: () => onRemove(field),
                  onStructuredEdit: field.kind == VaultFieldKind.totp
                      ? (onEditTotp == null ? null : () => onEditTotp!(field))
                      : field.kind == VaultFieldKind.attachment
                      ? (onEditAttachment == null
                            ? null
                            : () => onEditAttachment!(field))
                      : null,
                ),
            ],
          ),
        const SizedBox(height: LocalholdSpacing.lg),
        if (onAddTotp != null)
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: Text(LocalholdLocalizations.of(context).editorAddTotp),
            onTap: onAddTotp,
          ),
        if (onAddAttachment != null)
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(LocalholdLocalizations.of(context).editorAddAttachment),
            onTap: onAddAttachment,
          ),
        if (onAddCustomField != null)
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: Text(
              LocalholdLocalizations.of(context).editorAddCustomField,
            ),
            subtitle: Text(LocalholdLocalizations.of(context).premiumBadge),
            onTap: onAddCustomField,
          ),
        const SizedBox(height: LocalholdSpacing.xl),
        FilledButton(
          onPressed: controller.isCommitting ? null : onCommit,
          child: Text(LocalholdLocalizations.of(context).editorSaveRecord),
        ),
      ],
    );
  }
}

final class _PersistenceStatus extends StatelessWidget {
  const _PersistenceStatus({required this.status});

  final EditorPersistenceStatus status;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final message = switch (status) {
      EditorPersistenceStatus.idle => null,
      EditorPersistenceStatus.saving => strings.editorDraftSaving,
      EditorPersistenceStatus.saved => strings.editorDraftSaved,
      EditorPersistenceStatus.recoverableFailure => strings.editorDraftFailed,
      EditorPersistenceStatus.conflict => strings.editorDraftConflict,
    };
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: LocalholdSpacing.sm),
      child: Text(message, key: const ValueKey('editor_persistence_status')),
    );
  }
}

final class _EditorField extends StatefulWidget {
  const _EditorField({
    required this.field,
    required this.label,
    required this.warningCode,
    required this.onChanged,
    required this.onRemove,
    this.onStructuredEdit,
    super.key,
  });

  final VaultField field;
  final String label;
  final String? warningCode;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onStructuredEdit;

  @override
  State<_EditorField> createState() => _EditorFieldState();
}

final class _EditorFieldState extends State<_EditorField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.field.kind == VaultFieldKind.boolean) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.label),
        value: widget.field.value == true,
        onChanged: widget.onChanged,
        secondary: IconButton(
          tooltip: LocalholdLocalizations.of(context).editorRemoveField,
          onPressed: widget.onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      );
    }
    if (widget.field.kind == VaultFieldKind.totp ||
        widget.field.kind == VaultFieldKind.attachment) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.label),
        subtitle: Text(_structuredSummary(widget.field)),
        onTap: widget.onStructuredEdit,
        trailing: IconButton(
          tooltip: LocalholdLocalizations.of(context).editorRemoveField,
          onPressed: widget.onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      );
    }
    final secret = widget.field.kind == VaultFieldKind.secret;
    return Padding(
      padding: const EdgeInsets.only(bottom: LocalholdSpacing.sm),
      child: TextFormField(
        key: ValueKey('editor_field_${widget.field.id.value}'),
        initialValue: widget.field.value?.toString() ?? '',
        obscureText: secret && !_revealed,
        maxLines: secret
            ? 1
            : widget.field.kind == VaultFieldKind.note
            ? 4
            : 1,
        keyboardType: _keyboard(widget.field.kind),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: _warning(context, widget.warningCode),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (secret)
                IconButton(
                  tooltip: _revealed
                      ? LocalholdLocalizations.of(context).recordViewHide
                      : LocalholdLocalizations.of(context).recordViewReveal,
                  onPressed: () => setState(() => _revealed = !_revealed),
                  icon: Icon(
                    _revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              IconButton(
                tooltip: LocalholdLocalizations.of(context).editorRemoveField,
                onPressed: widget.onRemove,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }

  TextInputType _keyboard(VaultFieldKind kind) => switch (kind) {
    VaultFieldKind.email => TextInputType.emailAddress,
    VaultFieldKind.phone => TextInputType.phone,
    VaultFieldKind.url => TextInputType.url,
    VaultFieldKind.number || VaultFieldKind.money =>
      const TextInputType.numberWithOptions(decimal: true, signed: true),
    _ => TextInputType.text,
  };

  String _structuredSummary(VaultField field) {
    final value = field.value;
    if (value is! Map) return '';
    if (field.kind == VaultFieldKind.totp) {
      return [
        value['issuer'],
        value['account'],
      ].whereType<String>().where((item) => item.isNotEmpty).join(' — ');
    }
    return value['displayName']?.toString() ?? '';
  }

  String? _warning(BuildContext context, String? code) {
    final strings = LocalholdLocalizations.of(context);
    return switch (code) {
      'do_not_store_card_pin' => strings.warningDoNotStoreCardPin,
      'localhold_is_not_a_wallet' => strings.warningLocalholdNotWallet,
      _ => null,
    };
  }
}

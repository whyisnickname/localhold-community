// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'template_field_localizations.dart';

final class RecordConversionScreen extends StatelessWidget {
  const RecordConversionScreen({
    required this.preview,
    required this.onApply,
    super.key,
  });

  final RecordConversionPreview preview;
  final ValueChanged<EditorDraftSnapshot> onApply;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.conversionTitle)),
      body: ListView(
        padding: const EdgeInsets.all(LocalholdSpacing.md),
        children: [
          for (final field in preview.fields)
            ListTile(
              leading: Icon(_icon(field.disposition)),
              title: Text(
                localizedTemplateFieldLabel(
                  strings,
                  preview.source.typeId,
                  field.source,
                ),
              ),
              subtitle: Text(_status(strings, field.disposition)),
            ),
          const SizedBox(height: LocalholdSpacing.lg),
          FilledButton(
            onPressed: () => onApply(preview.apply(now: DateTime.now())),
            child: Text(strings.conversionApply),
          ),
        ],
      ),
    );
  }

  IconData _icon(ConversionDisposition disposition) => switch (disposition) {
    ConversionDisposition.mapped => Icons.check_circle_outline,
    ConversionDisposition.unmapped => Icons.add_circle_outline,
    ConversionDisposition.incompatible => Icons.warning_amber_outlined,
  };

  String _status(
    LocalholdLocalizations strings,
    ConversionDisposition disposition,
  ) => switch (disposition) {
    ConversionDisposition.mapped => strings.conversionMapped,
    ConversionDisposition.unmapped => strings.conversionUnmapped,
    ConversionDisposition.incompatible => strings.conversionIncompatible,
  };
}

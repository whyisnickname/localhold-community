// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

typedef VaultLabelBuilder = String Function(VaultUnlockEntry entry);

String localizedLockedVaultLabel(
  LocalholdLocalizations strings,
  VaultUnlockEntry entry,
) => entry.publicLabel ?? strings.unlockNeutralVault(entry.ordinal);

final class VaultPicker extends StatelessWidget {
  const VaultPicker({
    required this.entries,
    required this.selectedVaultId,
    required this.onSelected,
    this.labelBuilder,
    super.key,
  });

  final List<VaultUnlockEntry> entries;
  final VaultId? selectedVaultId;
  final ValueChanged<VaultId> onSelected;
  final VaultLabelBuilder? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return Semantics(
      container: true,
      label: strings.unlockChooseVault,
      child: RadioGroup<VaultId>(
        groupValue: selectedVaultId,
        onChanged: (value) {
          if (value != null) onSelected(value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in entries)
              RadioListTile<VaultId>(
                value: entry.vaultId,
                title: Text(
                  labelBuilder?.call(entry) ??
                      localizedLockedVaultLabel(strings, entry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';
import 'identifiers.dart';

final class VaultUnlockEntry {
  VaultUnlockEntry({
    required this.vaultId,
    required this.ordinal,
    this.publicLabel,
  }) {
    final label = publicLabel;
    if (ordinal < 1 ||
        (label != null &&
            (label.trim().isEmpty || label.runes.length > maximumLabelRunes))) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  static const int maximumLabelRunes = 80;

  final VaultId vaultId;
  final int ordinal;

  /// Explicitly non-secret text that may be rendered before unlock.
  /// Null means the UI must use a localized neutral ordinal label.
  final String? publicLabel;
}

abstract interface class VaultUnlockDirectoryStore {
  Future<List<VaultUnlockEntry>> list();

  Future<VaultUnlockEntry> register(VaultId id, {String? publicLabel});

  Future<void> updatePublicLabel(VaultId id, String? publicLabel);

  Future<void> remove(VaultId id);
}

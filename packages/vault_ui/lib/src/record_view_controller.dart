// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

final class RecordViewController extends ChangeNotifier {
  RecordViewController({required this.record, required this.template}) {
    if (record.typeId != template.stableId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final VaultRecord record;
  final RecordTypeDefinition template;
  final Set<String> _revealedFieldIds = {};

  bool isRevealed(FieldId fieldId) => _revealedFieldIds.contains(fieldId.value);

  void toggleReveal(FieldId fieldId) {
    if (!_revealedFieldIds.add(fieldId.value)) {
      _revealedFieldIds.remove(fieldId.value);
    }
    notifyListeners();
  }

  void clearReveals({bool notify = true}) {
    if (_revealedFieldIds.isEmpty) return;
    _revealedFieldIds.clear();
    if (notify) notifyListeners();
  }
}

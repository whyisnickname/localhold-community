// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test('newer pending autosave replaces work that has not started', () async {
    final coordinator = DraftAutosaveCoordinator(idleDelay: Duration.zero);
    var writes = 0;
    coordinator.schedule(() async {
      writes += 100;
      return DraftSaveResult.saved(_draft());
    });
    coordinator.schedule(() async {
      writes += 1;
      return DraftSaveResult.saved(_draft());
    });

    expect(await coordinator.flush(), isNotNull);
    expect(writes, 1);
    await coordinator.dispose();
  });

  test('discard without flush does not run pending write', () async {
    final coordinator = DraftAutosaveCoordinator(
      idleDelay: const Duration(days: 1),
    );
    var wrote = false;
    coordinator.schedule(() async {
      wrote = true;
      return DraftSaveResult.saved(_draft());
    });
    await coordinator.dispose(flushPending: false);
    expect(wrote, isFalse);
  });
}

VaultDraft _draft() {
  final now = DateTime.utc(2026, 8, 26);
  return VaultDraft(
    id: DraftId.generate(),
    recordSnapshot: VaultRecord(
      id: RecordId.generate(),
      typeId: BuiltInRecordTypes.secureNote,
      fields: [
        VaultField(
          id: FieldId.generate(),
          kind: VaultFieldKind.note,
          label: 'Note',
          value: 'draft',
          definitionId: 'note',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    ),
    updatedAt: now,
  );
}

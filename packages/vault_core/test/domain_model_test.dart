// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  group('vault domain', () {
    test('record requires a non-empty user value', () {
      expect(
        () => _record(value: ''),
        throwsA(_failure(VaultFailureCode.invalidInput)),
      );
      expect(_record(value: 'alice').encodedBytes, isNotEmpty);
    });

    test('record codec preserves stable identifiers and Unicode', () {
      const codec = VaultRecordCodec();
      final original = _record(value: 'Élodie 🔐');
      final decoded = codec.decode(codec.encode(original));

      expect(decoded.id.value, original.id.value);
      expect(decoded.fields.single.value, 'Élodie 🔐');
      expect(decoded.fields.single.definitionId, 'username');
    });

    test('canonical folder and tag duplicates are rejected', () {
      expect(
        () => VaultOrganization(
          id: OrganizationId.generate(),
          folders: [
            VaultFolder(id: FolderId.generate(), name: 'Café'),
            VaultFolder(id: FolderId.generate(), name: 'Café'),
          ],
          tags: const [],
        ),
        throwsA(_failure(VaultFailureCode.revisionConflict)),
      );
    });

    test('built-in templates have globally unique stable IDs', () {
      final templates = BuiltInTemplateCatalog.all;
      expect(templates, isNotEmpty);
      expect(
        templates.map((value) => value.stableId).toSet().length,
        templates.length,
      );
      for (final template in templates) {
        expect(
          template.fields.map((field) => field.stableId).toSet().length,
          template.fields.length,
        );
      }
    });

    test('Free creation policy denies Premium-only additions', () {
      const policy = CommunityFreeVaultCreationPolicy();
      for (final capability in VaultCreationCapability.values) {
        expect(
          () => policy.requireAllowed(capability),
          throwsA(_failure(VaultFailureCode.capabilityUnavailable)),
        );
      }
    });

    test('trash expiry uses the timestamp of the trash transition', () {
      final now = DateTime.utc(2026, 8, 26);
      final existing = _record(value: 'value').copyWith(
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 40)),
      );
      final trashed = moveRecordToTrash(
        existing,
        now.subtract(const Duration(days: 31)),
      );
      expect(expiredTrashRecords([trashed], now: now), [trashed]);
      expect(
        expiredTrashRecords(
          [trashed],
          now: now,
          retention: const Duration(days: 90),
        ),
        isEmpty,
      );
    });
  });
}

VaultRecord _record({required String value}) {
  final now = DateTime.utc(2026, 8, 25);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: BuiltInRecordTypes.account,
    fields: [
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.username,
        label: 'Username',
        value: value,
        definitionId: 'username',
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test('document AAD binds the vault and key generation', () async {
    final repository = _MemoryRepository();
    final cipher = _PassThroughCipher();
    final service = EncryptedRecordService(
      repository: repository,
      cipher: cipher,
      creationPolicy: const _AllowPolicy(),
    );

    await service.create(_record());

    final aad = ascii.decode(cipher.lastAuthenticatedData!);
    expect(aad, contains('|${cipher.vaultId}|vault_document|'));
    expect(aad, endsWith('|${cipher.keyGenerationId}'));
  });

  test(
    'stale record update creates a conflict copy without overwrite',
    () async {
      final repository = _MemoryRepository();
      final service = EncryptedRecordService(
        repository: repository,
        cipher: _PassThroughCipher(),
        creationPolicy: const _AllowPolicy(),
      );
      final original = _record();
      await service.create(original);

      final result = await service.update(
        proposed: original.copyWith(
          fields: [_field('changed', id: original.fields.single.id)],
        ),
        expectedRevision: 7,
        now: original.updatedAt.add(const Duration(minutes: 1)),
      );

      expect(result.hasConflict, isTrue);
      expect(result.conflictCopy!.conflictOf, original.id);
      expect(result.conflictCopy!.revision, 1);
      expect((await service.read(original.id))!.revision, 1);
    },
  );

  test(
    'Premium expiry keeps existing TOTP editable but denies a new field',
    () async {
      final repository = _MemoryRepository();
      final cipher = _PassThroughCipher();
      final premium = EncryptedRecordService(
        repository: repository,
        cipher: cipher,
        creationPolicy: const _AllowPolicy(),
      );
      final now = DateTime.utc(2026, 8, 26);
      final totpField = VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.totp,
        label: 'TOTP',
        value: 'encrypted-secret-model',
        definitionId: 'totp',
      );
      final original = VaultRecord(
        id: RecordId.generate(),
        typeId: BuiltInRecordTypes.account,
        fields: [totpField],
        createdAt: now,
        updatedAt: now,
      );
      await premium.create(original);
      final expired = EncryptedRecordService(
        repository: repository,
        cipher: cipher,
        creationPolicy: const CommunityFreeVaultCreationPolicy(),
      );

      final edited = await expired.update(
        proposed: original.copyWith(
          fields: [
            VaultField(
              id: totpField.id,
              kind: VaultFieldKind.totp,
              label: 'TOTP',
              value: 'updated-existing-secret',
              definitionId: 'totp',
            ),
          ],
        ),
        expectedRevision: 1,
        now: now.add(const Duration(minutes: 1)),
      );
      expect(edited.record!.revision, 2);

      await expectLater(
        expired.update(
          proposed: edited.record!.copyWith(
            fields: [
              ...edited.record!.fields,
              VaultField(
                id: FieldId.generate(),
                kind: VaultFieldKind.totp,
                label: 'Second TOTP',
                value: 'new-secret',
                definitionId: 'totp',
              ),
            ],
          ),
          expectedRevision: 2,
          now: now.add(const Duration(minutes: 2)),
        ),
        throwsA(_failure(VaultFailureCode.capabilityUnavailable)),
      );
    },
  );

  test(
    'multi-record update fails closed without an atomic repository',
    () async {
      final repository = _MemoryRepository();
      final service = EncryptedRecordService(
        repository: repository,
        cipher: _PassThroughCipher(),
        creationPolicy: const _AllowPolicy(),
      );
      final first = _record();
      final second = _record();
      await service.create(first);
      await service.create(second);

      await expectLater(
        service.updateMany(
          proposed: [
            first.copyWith(favorite: true),
            second.copyWith(favorite: true),
          ],
          now: DateTime.utc(2026, 9, 5),
        ),
        throwsA(_failure(VaultFailureCode.capabilityUnavailable)),
      );

      expect((await service.read(first.id))!.favorite, isFalse);
      expect((await service.read(second.id))!.favorite, isFalse);
    },
  );

  test('metadata batch rejects field changes before any mutation', () async {
    final repository = _MemoryRepository();
    final service = EncryptedRecordService(
      repository: repository,
      cipher: _PassThroughCipher(),
      creationPolicy: const _AllowPolicy(),
    );
    final first = _record();
    final second = _record();
    await service.create(first);
    await service.create(second);

    await expectLater(
      service.updateMany(
        proposed: [
          first.copyWith(
            fields: [_field('changed', id: first.fields.single.id)],
          ),
          second,
        ],
        now: DateTime.utc(2026, 9, 5),
      ),
      throwsA(_failure(VaultFailureCode.invalidInput)),
    );
    expect((await service.read(first.id))!.fields.single.value, 'original');
  });
}

VaultRecord _record() {
  final now = DateTime.utc(2026, 8, 26);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: BuiltInRecordTypes.account,
    fields: [_field('original')],
    createdAt: now,
    updatedAt: now,
  );
}

VaultField _field(String value, {FieldId? id}) => VaultField(
  id: id ?? FieldId.generate(),
  kind: VaultFieldKind.text,
  label: 'Title',
  value: value,
  definitionId: 'title',
);

final class _AllowPolicy implements VaultCreationPolicy {
  const _AllowPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

final class _PassThroughCipher implements PayloadCipher {
  Uint8List? lastAuthenticatedData;

  @override
  String get vaultId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  String get keyGenerationId => 'BBBBBBBBBBBBBBBBBBBBBB';

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async => Uint8List.fromList(envelope);

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async {
    lastAuthenticatedData = Uint8List.fromList(authenticatedData);
    return Uint8List.fromList(plaintext);
  }
}

final class _MemoryRepository implements CiphertextRepository {
  final Map<String, EncryptedObject> values = {};

  @override
  Future<void> create(EncryptedObject object) async {
    if (values.containsKey(object.objectId)) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values[object.objectId] = object;
  }

  @override
  Future<void> quarantine({
    required String objectId,
    required int expectedRevision,
    required VaultFailureCode reason,
  }) async {
    values.remove(objectId);
  }

  @override
  Future<EncryptedObject?> read(String objectId) async => values[objectId];

  @override
  Future<List<EncryptedObject>> readAll() async => List.of(values.values);

  @override
  Future<void> remove({
    required String objectId,
    required int expectedRevision,
  }) async {
    final current = values[objectId];
    if (current == null || current.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values.remove(objectId);
  }

  @override
  Future<void> replace({
    required EncryptedObject object,
    required int expectedRevision,
  }) async {
    final current = values[object.objectId];
    if (current == null || current.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values[object.objectId] = object;
  }

  @override
  Stream<List<EncryptedObject>> watchAll() =>
      Stream.value(List.of(values.values));
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

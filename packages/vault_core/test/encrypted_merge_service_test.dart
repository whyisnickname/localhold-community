// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'encrypted merge commits target and trashed source atomically',
    () async {
      final repository = _AtomicMemoryRepository();
      final service = _service(repository);
      final target = _record('Target', 'old-user', favorite: true);
      final source = _record('Source', 'new-user', pinned: true);
      await service.create(target);
      await service.create(source);
      final preview = RecordMergePlanner(
        definitions: BuiltInTemplateCatalog.all,
      ).prepare(target: target, source: source);
      final choices = {
        for (final slot in preview.slots)
          slot.id: slot.sourceField?.definitionId == 'username'
              ? MergeFieldChoice.source
              : MergeFieldChoice.target,
      };

      final result = await service.merge(
        command: RecordMergeCommand(
          targetId: target.id,
          sourceId: source.id,
          expectedTargetRevision: 1,
          expectedSourceRevision: 1,
          choices: choices,
        ),
        now: DateTime.utc(2026, 9, 5, 12),
      );

      expect(result.target.revision, 2);
      expect(result.target.favorite, isTrue);
      expect(result.target.pinned, isTrue);
      expect(
        result.target.fields
            .firstWhere((field) => field.definitionId == 'username')
            .value,
        'new-user',
      );
      expect(result.source.revision, 2);
      expect(result.source.lifecycle, RecordLifecycle.trashed);
      expect(
        (await service.read(source.id))!.lifecycle,
        RecordLifecycle.trashed,
      );
    },
  );

  test('stale merge leaves both ciphertext objects unchanged', () async {
    final repository = _AtomicMemoryRepository();
    final service = _service(repository);
    final target = _record('Target', 'old-user');
    final source = _record('Source', 'new-user');
    await service.create(target);
    await service.create(source);
    final preview = RecordMergePlanner(definitions: BuiltInTemplateCatalog.all)
        .prepare(target: target, source: source);

    await expectLater(
      service.merge(
        command: RecordMergeCommand(
          targetId: target.id,
          sourceId: source.id,
          expectedTargetRevision: 7,
          expectedSourceRevision: 1,
          choices: {
            for (final slot in preview.slots) slot.id: MergeFieldChoice.target,
          },
        ),
        now: DateTime.utc(2026, 9, 5, 12),
      ),
      throwsA(_failure(VaultFailureCode.revisionConflict)),
    );

    expect((await service.read(target.id))!.revision, 1);
    expect((await service.read(source.id))!.lifecycle, RecordLifecycle.active);
  });

  test('merge fails closed when repository has no atomic capability', () async {
    final repository = _NonAtomicMemoryRepository();
    final service = _service(repository);
    final target = _record('Target', 'old-user');
    final source = _record('Source', 'new-user');
    await service.create(target);
    await service.create(source);
    final preview = RecordMergePlanner(definitions: BuiltInTemplateCatalog.all)
        .prepare(target: target, source: source);

    await expectLater(
      service.merge(
        command: RecordMergeCommand(
          targetId: target.id,
          sourceId: source.id,
          expectedTargetRevision: 1,
          expectedSourceRevision: 1,
          choices: {
            for (final slot in preview.slots) slot.id: MergeFieldChoice.target,
          },
        ),
        now: DateTime.utc(2026, 9, 5, 12),
      ),
      throwsA(_failure(VaultFailureCode.capabilityUnavailable)),
    );

    expect((await service.read(target.id))!.revision, 1);
    expect((await service.read(source.id))!.revision, 1);
  });
}

EncryptedRecordService _service(CiphertextRepository repository) =>
    EncryptedRecordService(
      repository: repository,
      cipher: const _PassThroughCipher(),
      creationPolicy: const _AllowPolicy(),
    );

VaultRecord _record(
  String title,
  String username, {
  bool favorite = false,
  bool pinned = false,
}) {
  final now = DateTime.utc(2026, 9, 5);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: BuiltInRecordTypes.account,
    fields: [
      _field('title', VaultFieldKind.text, title),
      _field('username', VaultFieldKind.username, username),
    ],
    createdAt: now,
    updatedAt: now,
    favorite: favorite,
    pinned: pinned,
  );
}

VaultField _field(String id, VaultFieldKind kind, String value) => VaultField(
  id: FieldId.generate(),
  kind: kind,
  label: id,
  value: value,
  definitionId: id,
);

final class _AllowPolicy implements VaultCreationPolicy {
  const _AllowPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

final class _PassThroughCipher implements PayloadCipher {
  const _PassThroughCipher();

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
  }) async => Uint8List.fromList(plaintext);
}

base class _NonAtomicMemoryRepository implements CiphertextRepository {
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
  }) async => values.remove(objectId);

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

final class _AtomicMemoryRepository extends _NonAtomicMemoryRepository
    implements AtomicCiphertextRepository {
  @override
  Future<void> replaceMany(
    Iterable<ExpectedEncryptedObject> replacements,
  ) async {
    final source = replacements.toList(growable: false);
    for (final replacement in source) {
      final current = values[replacement.object.objectId];
      if (current == null || current.revision != replacement.expectedRevision) {
        throw const VaultFailure(VaultFailureCode.revisionConflict);
      }
    }
    for (final replacement in source) {
      values[replacement.object.objectId] = replacement.object;
    }
  }
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

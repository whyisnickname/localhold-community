// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:test/test.dart';

void main() {
  late LocalholdVaultDatabase database;

  setUp(() {
    database = LocalholdVaultDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('repositories are strictly scoped to their vault', () async {
    final first = DriftCiphertextRepository(
      database,
      vaultId: VaultId.generate(),
    );
    final second = DriftCiphertextRepository(
      database,
      vaultId: VaultId.generate(),
    );
    final object = _object();

    await first.create(object);
    expect((await first.readAll()).single.objectId, object.objectId);
    expect(await second.readAll(), isEmpty);
    expect(await second.read(object.objectId), isNull);
  });

  test('replace requires the expected revision', () async {
    final repository = DriftCiphertextRepository(
      database,
      vaultId: VaultId.generate(),
    );
    final object = _object();
    await repository.create(object);

    await expectLater(
      repository.replace(
        object: _object(id: object.objectId, revision: 2),
        expectedRevision: 7,
      ),
      throwsA(_failure(VaultFailureCode.revisionConflict)),
    );
    expect((await repository.read(object.objectId))!.revision, 1);
  });

  test('quarantine is atomic and remains vault-scoped', () async {
    final vaultId = VaultId.generate();
    final repository = DriftCiphertextRepository(database, vaultId: vaultId);
    final object = _object();
    await repository.create(object);
    await repository.quarantine(
      objectId: object.objectId,
      expectedRevision: 1,
      reason: VaultFailureCode.integrityFailure,
    );

    expect(await repository.read(object.objectId), isNull);
    final row = await database.select(database.quarantinedObjects).getSingle();
    expect(row.vaultId, vaultId.value);
    expect(row.objectId, object.objectId);
    expect(row.reasonCode, VaultFailureCode.integrityFailure.name);
  });

  test('replaceMany is all-or-nothing on revision conflict', () async {
    final repository = DriftCiphertextRepository(
      database,
      vaultId: VaultId.generate(),
    );
    final first = _object();
    final second = _object();
    await repository.create(first);
    await repository.create(second);

    await expectLater(
      repository.replaceMany([
        ExpectedEncryptedObject(
          object: _object(id: first.objectId, revision: 2),
          expectedRevision: 1,
        ),
        ExpectedEncryptedObject(
          object: _object(id: second.objectId, revision: 2),
          expectedRevision: 9,
        ),
      ]),
      throwsA(_failure(VaultFailureCode.revisionConflict)),
    );

    expect((await repository.read(first.objectId))!.revision, 1);
    expect((await repository.read(second.objectId))!.revision, 1);
  });
}

EncryptedObject _object({String? id, int revision = 1}) => EncryptedObject(
  objectId: id ?? RecordId.generate().value,
  revision: revision,
  schemaVersion: 1,
  keyGenerationId: RecordId.generate().value,
  envelope: Uint8List.fromList([1, 2, 3]),
);

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

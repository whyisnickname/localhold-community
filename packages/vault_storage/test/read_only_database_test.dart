// SPDX-License-Identifier: MPL-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:test/test.dart';

void main() {
  test('explicit recovery database cannot mutate ciphertext', () async {
    final root = await Directory.systemTemp.createTemp('localhold-read-only-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final file = File('${root.path}${Platform.pathSeparator}vault.sqlite');
    final writable = await openNativeVaultDatabase(
      databaseFile: file,
      privateTemporaryDirectory: Directory(
        '${root.path}${Platform.pathSeparator}temp',
      ),
      backupExclusion: const _NoOpBackupExclusion(),
    );
    await writable.select(writable.encryptedObjects).get();
    await writable.close();

    final recovery = await openNativeVaultDatabaseReadOnly(databaseFile: file);
    addTearDown(() => recovery.close());
    expect(recovery.isReadOnly, isTrue);
    final repository = DriftCiphertextRepository(
      recovery,
      vaultId: VaultId.generate(),
    );
    await expectLater(
      repository.create(
        EncryptedObject(
          objectId: RecordId.generate().value,
          revision: 1,
          schemaVersion: 1,
          keyGenerationId: RecordId.generate().value,
          envelope: Uint8List.fromList([1]),
        ),
      ),
      throwsA(
        isA<VaultFailure>().having(
          (error) => error.code,
          'code',
          VaultFailureCode.readOnly,
        ),
      ),
    );
  });
}

final class _NoOpBackupExclusion implements BackupExclusionGateway {
  const _NoOpBackupExclusion();

  @override
  Future<void> excludeAbsolutePath(String absolutePath) async {}
}

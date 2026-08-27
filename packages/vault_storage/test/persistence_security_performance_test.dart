// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:test/test.dart';

void main() {
  test(
    'disk database, WAL, SHM and temp never contain plaintext sentinel',
    () async {
      const sentinel = 'LOCALHOLD_PLAINTEXT_SENTINEL_91f4d8c2';
      final root = await Directory.systemTemp.createTemp(
        'localhold-persistence-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final databaseFile = File(
        '${root.path}${Platform.pathSeparator}vault.sqlite',
      );
      final temporary = Directory('${root.path}${Platform.pathSeparator}temp');
      final exclusion = _RecordingBackupExclusion();
      final database = await openNativeVaultDatabase(
        databaseFile: databaseFile,
        privateTemporaryDirectory: temporary,
        backupExclusion: exclusion,
      );
      final vaultId = VaultId.parse('AAAAAAAAAAAAAAAAAAAAAA');
      final cipher = _XorCipher(vaultId: vaultId.value);
      final service = EncryptedRecordService(
        repository: DriftCiphertextRepository(database, vaultId: vaultId),
        cipher: cipher,
        creationPolicy: const _AllowCreationPolicy(),
      );

      await service.create(_record(1, sentinel));
      await database.customStatement('PRAGMA wal_checkpoint(PASSIVE)');
      final columns = await database
          .customSelect('PRAGMA table_info(encrypted_objects)')
          .get();
      expect(columns.map((row) => row.read<String>('name')).toSet(), {
        'vault_id',
        'object_id',
        'revision',
        'schema_version',
        'key_generation_id',
        'envelope',
      });
      expect(exclusion.paths.toSet(), {
        databaseFile.parent.absolute.path,
        temporary.absolute.path,
      });

      final needle = utf8.encode(sentinel);
      final files = await root
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      expect(files, isNotEmpty);
      for (final file in files) {
        expect(
          _containsBytes(await file.readAsBytes(), needle),
          isFalse,
          reason: 'plaintext sentinel in ${file.uri.pathSegments.last}',
        );
      }
      await database.close();
    },
  );

  test('ciphertext CRUD p95 stays within 250 ms', () async {
    final database = LocalholdVaultDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftCiphertextRepository(
      database,
      vaultId: VaultId.parse('BBBBBBBBBBBBBBBBBBBBBB'),
    );
    final createMicros = <int>[];
    final readMicros = <int>[];
    final replaceMicros = <int>[];
    const count = 250;

    for (var index = 0; index < count; index++) {
      final id = 'O${index.toString().padLeft(21, '0')}';
      final create = Stopwatch()..start();
      await repository.create(_object(id, revision: 1));
      createMicros.add((create..stop()).elapsedMicroseconds);

      final read = Stopwatch()..start();
      expect(await repository.read(id), isNotNull);
      readMicros.add((read..stop()).elapsedMicroseconds);

      final replace = Stopwatch()..start();
      await repository.replace(
        object: _object(id, revision: 2),
        expectedRevision: 1,
      );
      replaceMicros.add((replace..stop()).elapsedMicroseconds);
    }

    final createP95 = _p95(createMicros);
    final readP95 = _p95(readMicros);
    final replaceP95 = _p95(replaceMicros);
    // Secret-free benchmark evidence for the Stage 4 test runner.
    // ignore: avoid_print
    print(
      'STAGE4_CRUD create_p95_us=$createP95 read_p95_us=$readP95 '
      'replace_p95_us=$replaceP95 operations=$count',
    );
    for (final value in [createP95, readP95, replaceP95]) {
      expect(value, lessThanOrEqualTo(250000));
    }
  });
}

final class _RecordingBackupExclusion implements BackupExclusionGateway {
  final List<String> paths = [];

  @override
  Future<void> excludeAbsolutePath(String absolutePath) async {
    paths.add(absolutePath);
  }
}

final class _AllowCreationPolicy implements VaultCreationPolicy {
  const _AllowCreationPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

final class _XorCipher implements PayloadCipher {
  const _XorCipher({required this.vaultId});

  @override
  final String vaultId;

  @override
  String get keyGenerationId => 'KKKKKKKKKKKKKKKKKKKKKK';

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async => Uint8List.fromList(
    plaintext.map((value) => value ^ 0xa5).toList(growable: false),
  );

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async => Uint8List.fromList(
    envelope.map((value) => value ^ 0xa5).toList(growable: false),
  );
}

VaultRecord _record(int index, String value) {
  final now = DateTime.utc(2026, 8, 26);
  return VaultRecord(
    id: RecordId.parse('R${index.toString().padLeft(21, '0')}'),
    typeId: BuiltInRecordTypes.account,
    fields: [
      VaultField(
        id: FieldId.parse('F${index.toString().padLeft(21, '0')}'),
        kind: VaultFieldKind.secret,
        label: 'Secret',
        value: value,
        definitionId: 'password',
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

EncryptedObject _object(String id, {required int revision}) => EncryptedObject(
  objectId: id,
  revision: revision,
  schemaVersion: 1,
  keyGenerationId: 'KKKKKKKKKKKKKKKKKKKKKK',
  envelope: Uint8List.fromList([revision, 2, 3, 4]),
);

bool _containsBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return true;
  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var matches = true;
    for (var index = 0; index < needle.length; index++) {
      if (haystack[offset + index] != needle[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

int _p95(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[math.max(0, (sorted.length * 0.95).ceil() - 1)];
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'errors.dart';

final class EncryptedObject {
  const EncryptedObject({
    required this.objectId,
    required this.revision,
    required this.schemaVersion,
    required this.keyGenerationId,
    required this.envelope,
  });

  final String objectId;
  final int revision;
  final int schemaVersion;
  final String keyGenerationId;
  final Uint8List envelope;
}

abstract interface class CiphertextRepository {
  Future<EncryptedObject?> read(String objectId);

  Future<List<EncryptedObject>> readAll();

  Stream<List<EncryptedObject>> watchAll();

  Future<void> create(EncryptedObject object);

  Future<void> replace({
    required EncryptedObject object,
    required int expectedRevision,
  });

  Future<void> remove({
    required String objectId,
    required int expectedRevision,
  });

  Future<void> quarantine({
    required String objectId,
    required int expectedRevision,
    required VaultFailureCode reason,
  });
}

abstract interface class PayloadCipher {
  String get vaultId;

  String get keyGenerationId;

  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  });

  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  });
}

abstract final class ObjectAuthenticationData {
  static Uint8List encode({
    required String vaultId,
    required String objectId,
    required int revision,
    required int schemaVersion,
    required String keyGenerationId,
  }) => Uint8List.fromList(
    ascii.encode(
      'localhold.object.v1|$vaultId|vault_document|$objectId|$revision|$schemaVersion|$keyGenerationId',
    ),
  );
}

// SPDX-License-Identifier: MPL-2.0

import 'package:pigeon/pigeon.dart';

enum KeyBridgeErrorCode {
  invalidRequest,
  invalidCredentials,
  unsupportedVersion,
  sessionNotFound,
  sessionLocked,
  integrityFailure,
  payloadTooLarge,
  platformUnavailable,
  notImplemented,
  internalFailure,
}

class CreateVaultKeyRequest {
  CreateVaultKeyRequest({required this.masterPassword});

  Uint8List masterPassword;
}

class OpenVaultSessionRequest {
  OpenVaultSessionRequest({
    required this.masterPassword,
    required this.vaultKeyEnvelope,
  });

  Uint8List masterPassword;
  Uint8List vaultKeyEnvelope;
}

class RewrapVaultKeyRequest {
  RewrapVaultKeyRequest({
    required this.sessionHandle,
    required this.newMasterPassword,
  });

  String sessionHandle;
  Uint8List newMasterPassword;
}

class EncryptPayloadRequest {
  EncryptPayloadRequest({
    required this.sessionHandle,
    required this.plaintext,
    required this.authenticatedData,
  });

  String sessionHandle;
  Uint8List plaintext;
  Uint8List authenticatedData;
}

class DecryptPayloadRequest {
  DecryptPayloadRequest({
    required this.sessionHandle,
    required this.encryptedPayload,
    required this.authenticatedData,
  });

  String sessionHandle;
  Uint8List encryptedPayload;
  Uint8List authenticatedData;
}

class VaultSessionReply {
  VaultSessionReply({this.sessionHandle, this.vaultKeyEnvelope, this.error});

  String? sessionHandle;
  Uint8List? vaultKeyEnvelope;
  KeyBridgeErrorCode? error;
}

class PayloadReply {
  PayloadReply({this.payload, this.error});

  Uint8List? payload;
  KeyBridgeErrorCode? error;
}

class StatusReply {
  StatusReply({this.error});

  KeyBridgeErrorCode? error;
}

@HostApi()
abstract class KeyBridgeHostApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  VaultSessionReply createVaultKey(CreateVaultKeyRequest request);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  VaultSessionReply openVaultSession(OpenVaultSessionRequest request);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  PayloadReply encryptPayload(EncryptPayloadRequest request);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  PayloadReply decryptPayload(DecryptPayloadRequest request);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  PayloadReply rewrapVaultKey(RewrapVaultKeyRequest request);

  StatusReply closeSession(String sessionHandle);

  StatusReply closeAllSessions();
}

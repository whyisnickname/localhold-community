// SPDX-License-Identifier: MPL-2.0

import 'package:pigeon/pigeon.dart';

enum KeyBridgeErrorCode {
  invalidRequest,
  invalidCredentials,
  unsupportedVersion,
  sessionNotFound,
  sessionLocked,
  reauthenticationRequired,
  integrityFailure,
  payloadTooLarge,
  platformUnavailable,
  biometricUnavailable,
  biometricInvalidated,
  internalFailure,
}

class CreateVaultKeyRequest {
  CreateVaultKeyRequest({required this.vaultId, required this.masterPassword});

  String vaultId;
  Uint8List masterPassword;
}

class OpenVaultSessionRequest {
  OpenVaultSessionRequest({
    required this.vaultId,
    required this.masterPassword,
    required this.vaultKeyEnvelope,
  });

  String vaultId;
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
  VaultSessionReply({
    this.sessionHandle,
    this.keyGenerationId,
    this.vaultKeyEnvelope,
    this.error,
  });

  String? sessionHandle;
  String? keyGenerationId;
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

class RecoveryCeremonyReply {
  RecoveryCeremonyReply({
    this.ceremonyHandle,
    this.challengePositions,
    this.error,
  });

  String? ceremonyHandle;
  List<int>? challengePositions;
  KeyBridgeErrorCode? error;
}

class ConfirmRecoveryKeyRequest {
  ConfirmRecoveryKeyRequest({
    required this.ceremonyHandle,
    required this.challengeWordsUtf8,
  });

  String ceremonyHandle;
  Uint8List challengeWordsUtf8;
}

class OpenVaultWithRecoveryRequest {
  OpenVaultWithRecoveryRequest({
    required this.vaultId,
    required this.recoveryPhraseUtf8,
    required this.recoveryKeyEnvelope,
  });

  String vaultId;
  Uint8List recoveryPhraseUtf8;
  Uint8List recoveryKeyEnvelope;
}

class SensitiveClipboardRequest {
  SensitiveClipboardRequest({
    required this.utf8Value,
    required this.expirySeconds,
  });

  Uint8List utf8Value;
  int expirySeconds;
}

class BiometricStatusReply {
  BiometricStatusReply({
    required this.configured,
    this.invalidated = false,
    this.error,
  });

  bool configured;
  bool invalidated;
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

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RecoveryCeremonyReply beginRecoveryKey(String sessionHandle);

  StatusReply presentRecoveryKey(String ceremonyHandle);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  PayloadReply confirmRecoveryKey(ConfirmRecoveryKeyRequest request);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  VaultSessionReply openVaultWithRecovery(OpenVaultWithRecoveryRequest request);

  StatusReply cancelRecoveryKey(String ceremonyHandle);

  StatusReply setVaultPrivacyActive(bool active);

  StatusReply copySensitiveClipboard(SensitiveClipboardRequest request);

  StatusReply clearSensitiveClipboard();

  @async
  StatusReply enableBiometric(String sessionHandle);

  @async
  VaultSessionReply openVaultWithBiometric(String vaultId);

  @async
  StatusReply disableBiometric(String sessionHandle);

  BiometricStatusReply biometricStatus(String vaultId);

  StatusReply excludePathFromBackup(String absolutePath);

  StatusReply closeSession(String sessionHandle);

  StatusReply closeAllSessions();
}

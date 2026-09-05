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

enum PlatformFeatureErrorCode {
  invalidRequest,
  permissionDenied,
  permissionRestricted,
  notFound,
  platformUnavailable,
  internalFailure,
}

enum NotificationPermissionCode {
  notDetermined,
  denied,
  restricted,
  authorized,
}

enum WallClockResolutionCode { unique, earlier, later, gapAdjusted }

enum ShareKindCode { text, url, file, image }

class FeatureStatusReply {
  FeatureStatusReply({this.error});
  PlatformFeatureErrorCode? error;
}

class NotificationPermissionReply {
  NotificationPermissionReply({required this.state, this.error});
  NotificationPermissionCode state;
  PlatformFeatureErrorCode? error;
}

class LauncherActionReply {
  LauncherActionReply({required this.actionCode, this.error});
  int actionCode;
  PlatformFeatureErrorCode? error;
}

class WallClockRequest {
  WallClockRequest({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.timeZoneId,
  });
  int year;
  int month;
  int day;
  int hour;
  int minute;
  String timeZoneId;
}

class WallClockReply {
  WallClockReply({
    required this.utcEpochMilliseconds,
    required this.resolution,
    this.error,
  });
  int utcEpochMilliseconds;
  WallClockResolutionCode resolution;
  PlatformFeatureErrorCode? error;
}

class SafeReminderRequest {
  SafeReminderRequest({
    required this.syntheticId,
    required this.utcEpochMilliseconds,
    required this.privacyCode,
    this.safeName,
    this.safeAmount,
  });
  String syntheticId;
  int utcEpochMilliseconds;
  int privacyCode;
  String? safeName;
  String? safeAmount;
}

class InboundShareDescriptorReply {
  InboundShareDescriptorReply({
    required this.id,
    required this.kind,
    required this.byteLength,
    required this.receivedUtcEpochMilliseconds,
    required this.expiresUtcEpochMilliseconds,
  });
  String id;
  ShareKindCode kind;
  int byteLength;
  int receivedUtcEpochMilliseconds;
  int expiresUtcEpochMilliseconds;
}

class InboundShareListReply {
  InboundShareListReply({required this.items, this.error});
  List<InboundShareDescriptorReply> items;
  PlatformFeatureErrorCode? error;
}

class InboundShareChunkRequest {
  InboundShareChunkRequest({
    required this.id,
    required this.offset,
    required this.maximumBytes,
  });
  String id;
  int offset;
  int maximumBytes;
}

class InboundShareChunkReply {
  InboundShareChunkReply({required this.bytes, required this.done, this.error});
  Uint8List bytes;
  bool done;
  PlatformFeatureErrorCode? error;
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

  @async
  NotificationPermissionReply notificationPermissionStatus();

  @async
  NotificationPermissionReply requestNotificationPermission();

  FeatureStatusReply openNotificationSettings();

  WallClockReply resolveWallClock(WallClockRequest request);

  @async
  FeatureStatusReply replaceReminder(SafeReminderRequest request);

  FeatureStatusReply cancelReminder(String syntheticId);

  FeatureStatusReply installLauncherShortcuts();

  LauncherActionReply consumeLauncherAction();

  InboundShareListReply listInboundShares();

  InboundShareChunkReply readInboundShareChunk(
    InboundShareChunkRequest request,
  );

  FeatureStatusReply deleteInboundShare(String id);

  FeatureStatusReply purgeExpiredInboundShares(int nowUtcEpochMilliseconds);

  StatusReply excludePathFromBackup(String absolutePath);

  StatusReply closeSession(String sessionHandle);

  StatusReply closeAllSessions();
}

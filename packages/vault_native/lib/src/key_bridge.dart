// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';

import 'key_bridge_messages.g.dart';

const int _maximumBridgePayloadBytes = 2 * 1024 * 1024;
const int _maximumAuthenticatedDataBytes = 4 * 1024;

/// A secret-free failure exposed by the key bridge facade.
final class KeyBridgeFailure implements Exception {
  const KeyBridgeFailure(this.code);

  final KeyBridgeErrorCode code;

  @override
  String toString() => 'KeyBridgeFailure(${code.name})';
}

/// Opaque capability for native process-local vault key state.
final class VaultSession {
  const VaultSession._(
    this._handle,
    this.keyGenerationId,
    this.vaultKeyEnvelope,
  );

  final String _handle;
  final String keyGenerationId;
  final Uint8List? vaultKeyEnvelope;

  String get opaqueReference => _handle;
}

/// Recovery phrase stays native-owned; Dart receives only this opaque ceremony.
final class RecoveryCeremony {
  const RecoveryCeremony._(this._handle, this.challengePositions);

  final String _handle;
  final List<int> challengePositions;
}

final class BiometricStatus {
  const BiometricStatus({required this.configured, required this.invalidated});

  final bool configured;
  final bool invalidated;
}

abstract interface class KeyBridgeTransport {
  Future<VaultSessionReply> createVaultKey(CreateVaultKeyRequest request);

  Future<VaultSessionReply> openVaultSession(OpenVaultSessionRequest request);

  Future<PayloadReply> encryptPayload(EncryptPayloadRequest request);

  Future<PayloadReply> decryptPayload(DecryptPayloadRequest request);

  Future<PayloadReply> rewrapVaultKey(RewrapVaultKeyRequest request);

  Future<RecoveryCeremonyReply> beginRecoveryKey(String sessionHandle);

  Future<StatusReply> presentRecoveryKey(String ceremonyHandle);

  Future<PayloadReply> confirmRecoveryKey(ConfirmRecoveryKeyRequest request);

  Future<VaultSessionReply> openVaultWithRecovery(
    OpenVaultWithRecoveryRequest request,
  );

  Future<StatusReply> cancelRecoveryKey(String ceremonyHandle);

  Future<StatusReply> setVaultPrivacyActive(bool active);

  Future<StatusReply> copySensitiveClipboard(SensitiveClipboardRequest request);

  Future<StatusReply> clearSensitiveClipboard();

  Future<StatusReply> enableBiometric(String sessionHandle);

  Future<VaultSessionReply> openVaultWithBiometric(String vaultId);

  Future<StatusReply> disableBiometric(String sessionHandle);

  Future<BiometricStatusReply> biometricStatus(String vaultId);

  Future<StatusReply> excludePathFromBackup(String absolutePath);

  Future<StatusReply> closeSession(String sessionHandle);

  Future<StatusReply> closeAllSessions();
}

final class PigeonKeyBridgeTransport implements KeyBridgeTransport {
  PigeonKeyBridgeTransport([KeyBridgeHostApi? api])
    : _api = api ?? KeyBridgeHostApi();

  final KeyBridgeHostApi _api;

  @override
  Future<VaultSessionReply> createVaultKey(CreateVaultKeyRequest request) =>
      _api.createVaultKey(request);

  @override
  Future<VaultSessionReply> openVaultSession(OpenVaultSessionRequest request) =>
      _api.openVaultSession(request);

  @override
  Future<PayloadReply> encryptPayload(EncryptPayloadRequest request) =>
      _api.encryptPayload(request);

  @override
  Future<PayloadReply> decryptPayload(DecryptPayloadRequest request) =>
      _api.decryptPayload(request);

  @override
  Future<PayloadReply> rewrapVaultKey(RewrapVaultKeyRequest request) =>
      _api.rewrapVaultKey(request);

  @override
  Future<RecoveryCeremonyReply> beginRecoveryKey(String sessionHandle) =>
      _api.beginRecoveryKey(sessionHandle);

  @override
  Future<StatusReply> presentRecoveryKey(String ceremonyHandle) =>
      _api.presentRecoveryKey(ceremonyHandle);

  @override
  Future<PayloadReply> confirmRecoveryKey(ConfirmRecoveryKeyRequest request) =>
      _api.confirmRecoveryKey(request);

  @override
  Future<VaultSessionReply> openVaultWithRecovery(
    OpenVaultWithRecoveryRequest request,
  ) => _api.openVaultWithRecovery(request);

  @override
  Future<StatusReply> cancelRecoveryKey(String ceremonyHandle) =>
      _api.cancelRecoveryKey(ceremonyHandle);

  @override
  Future<StatusReply> setVaultPrivacyActive(bool active) =>
      _api.setVaultPrivacyActive(active);

  @override
  Future<StatusReply> copySensitiveClipboard(
    SensitiveClipboardRequest request,
  ) => _api.copySensitiveClipboard(request);

  @override
  Future<StatusReply> clearSensitiveClipboard() =>
      _api.clearSensitiveClipboard();

  @override
  Future<StatusReply> enableBiometric(String sessionHandle) =>
      _api.enableBiometric(sessionHandle);

  @override
  Future<VaultSessionReply> openVaultWithBiometric(String vaultId) =>
      _api.openVaultWithBiometric(vaultId);

  @override
  Future<StatusReply> disableBiometric(String sessionHandle) =>
      _api.disableBiometric(sessionHandle);

  @override
  Future<BiometricStatusReply> biometricStatus(String vaultId) =>
      _api.biometricStatus(vaultId);

  @override
  Future<StatusReply> excludePathFromBackup(String absolutePath) =>
      _api.excludePathFromBackup(absolutePath);

  @override
  Future<StatusReply> closeSession(String sessionHandle) =>
      _api.closeSession(sessionHandle);

  @override
  Future<StatusReply> closeAllSessions() => _api.closeAllSessions();
}

/// Validates the public contract and consumes mutable secret input buffers.
final class LocalholdKeyBridge {
  LocalholdKeyBridge({KeyBridgeTransport? transport})
    : _transport = transport ?? PigeonKeyBridgeTransport();

  final KeyBridgeTransport _transport;

  Future<VaultSession> createVaultKey({
    required String vaultId,
    required Uint8List masterPassword,
  }) async {
    try {
      _requireNonEmpty(masterPassword);
      final reply = await _guard(
        () => _transport.createVaultKey(
          CreateVaultKeyRequest(
            vaultId: vaultId,
            masterPassword: masterPassword,
          ),
        ),
      );
      return _sessionFrom(reply, requiresEnvelope: true);
    } finally {
      _wipe(masterPassword);
    }
  }

  Future<VaultSession> openVaultSession({
    required String vaultId,
    required Uint8List masterPassword,
    required Uint8List vaultKeyEnvelope,
  }) async {
    try {
      _requireNonEmpty(masterPassword);
      _requireBounded(vaultKeyEnvelope);
      final reply = await _guard(
        () => _transport.openVaultSession(
          OpenVaultSessionRequest(
            vaultId: vaultId,
            masterPassword: masterPassword,
            vaultKeyEnvelope: vaultKeyEnvelope,
          ),
        ),
      );
      return _sessionFrom(reply);
    } finally {
      _wipe(masterPassword);
    }
  }

  Future<Uint8List> encryptPayload({
    required VaultSession session,
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async {
    try {
      _requireHandle(session._handle);
      _requireBounded(plaintext);
      _requireAuthenticatedData(authenticatedData);
      final reply = await _guard(
        () => _transport.encryptPayload(
          EncryptPayloadRequest(
            sessionHandle: session._handle,
            plaintext: plaintext,
            authenticatedData: authenticatedData,
          ),
        ),
      );
      return _payloadFrom(reply);
    } finally {
      _wipe(plaintext);
    }
  }

  Future<Uint8List> decryptPayload({
    required VaultSession session,
    required Uint8List encryptedPayload,
    required Uint8List authenticatedData,
  }) async {
    _requireHandle(session._handle);
    _requireBounded(encryptedPayload);
    _requireAuthenticatedData(authenticatedData);
    final reply = await _guard(
      () => _transport.decryptPayload(
        DecryptPayloadRequest(
          sessionHandle: session._handle,
          encryptedPayload: encryptedPayload,
          authenticatedData: authenticatedData,
        ),
      ),
    );
    return _payloadFrom(reply);
  }

  Future<Uint8List> rewrapVaultKey({
    required VaultSession session,
    required Uint8List newMasterPassword,
  }) async {
    try {
      _requireHandle(session._handle);
      _requireNonEmpty(newMasterPassword);
      final reply = await _guard(
        () => _transport.rewrapVaultKey(
          RewrapVaultKeyRequest(
            sessionHandle: session._handle,
            newMasterPassword: newMasterPassword,
          ),
        ),
      );
      return _payloadFrom(reply);
    } finally {
      _wipe(newMasterPassword);
    }
  }

  Future<RecoveryCeremony> beginRecoveryKey(VaultSession session) async {
    _requireHandle(session._handle);
    final reply = await _guard(
      () => _transport.beginRecoveryKey(session._handle),
    );
    _throwReplyError(reply.error);
    final handle = reply.ceremonyHandle;
    final positions = reply.challengePositions;
    if (handle == null ||
        handle.isEmpty ||
        positions == null ||
        positions.length != 4 ||
        positions.toSet().length != 4 ||
        positions.any((value) => value < 1 || value > 24)) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.internalFailure);
    }
    return RecoveryCeremony._(handle, List<int>.unmodifiable(positions));
  }

  Future<void> presentRecoveryKey(RecoveryCeremony ceremony) async {
    _requireHandle(ceremony._handle);
    _statusFrom(
      await _guard(() => _transport.presentRecoveryKey(ceremony._handle)),
    );
  }

  Future<Uint8List> confirmRecoveryKey({
    required RecoveryCeremony ceremony,
    required Uint8List challengeWordsUtf8,
  }) async {
    try {
      _requireHandle(ceremony._handle);
      _requireRecoveryWords(challengeWordsUtf8, expectedWords: 4);
      final reply = await _guard(
        () => _transport.confirmRecoveryKey(
          ConfirmRecoveryKeyRequest(
            ceremonyHandle: ceremony._handle,
            challengeWordsUtf8: challengeWordsUtf8,
          ),
        ),
      );
      return _payloadFrom(reply);
    } finally {
      _wipe(challengeWordsUtf8);
    }
  }

  Future<VaultSession> openVaultWithRecovery({
    required String vaultId,
    required Uint8List recoveryPhraseUtf8,
    required Uint8List recoveryKeyEnvelope,
  }) async {
    try {
      _requireRecoveryWords(recoveryPhraseUtf8, expectedWords: 24);
      _requireBounded(recoveryKeyEnvelope);
      final reply = await _guard(
        () => _transport.openVaultWithRecovery(
          OpenVaultWithRecoveryRequest(
            vaultId: vaultId,
            recoveryPhraseUtf8: recoveryPhraseUtf8,
            recoveryKeyEnvelope: recoveryKeyEnvelope,
          ),
        ),
      );
      return _sessionFrom(reply);
    } finally {
      _wipe(recoveryPhraseUtf8);
    }
  }

  Future<void> cancelRecoveryKey(RecoveryCeremony ceremony) async {
    _requireHandle(ceremony._handle);
    _statusFrom(
      await _guard(() => _transport.cancelRecoveryKey(ceremony._handle)),
    );
  }

  Future<void> setVaultPrivacyActive(bool active) async {
    _statusFrom(await _guard(() => _transport.setVaultPrivacyActive(active)));
  }

  Future<void> copySensitiveClipboard({
    required Uint8List utf8Value,
    required int expirySeconds,
  }) async {
    try {
      if (utf8Value.isEmpty ||
          utf8Value.lengthInBytes > _maximumBridgePayloadBytes ||
          !const {15, 30, 60, 120}.contains(expirySeconds)) {
        throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
      }
      _statusFrom(
        await _guard(
          () => _transport.copySensitiveClipboard(
            SensitiveClipboardRequest(
              utf8Value: utf8Value,
              expirySeconds: expirySeconds,
            ),
          ),
        ),
      );
    } finally {
      _wipe(utf8Value);
    }
  }

  Future<void> clearSensitiveClipboard() async {
    _statusFrom(await _guard(_transport.clearSensitiveClipboard));
  }

  Future<void> enableBiometric(VaultSession session) async {
    _requireHandle(session._handle);
    _statusFrom(
      await _guard(() => _transport.enableBiometric(session._handle)),
    );
  }

  Future<VaultSession> openVaultWithBiometric(String vaultId) async {
    final reply = await _guard(
      () => _transport.openVaultWithBiometric(vaultId),
    );
    return _sessionFrom(reply);
  }

  Future<void> disableBiometric(VaultSession session) async {
    _requireHandle(session._handle);
    _statusFrom(
      await _guard(() => _transport.disableBiometric(session._handle)),
    );
  }

  Future<BiometricStatus> biometricStatus(String vaultId) async {
    final reply = await _guard(() => _transport.biometricStatus(vaultId));
    _throwReplyError(reply.error);
    return BiometricStatus(
      configured: reply.configured,
      invalidated: reply.invalidated,
    );
  }

  Future<void> excludePathFromBackup(String absolutePath) async {
    if (absolutePath.isEmpty || absolutePath.length > 4096) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
    }
    _statusFrom(
      await _guard(() => _transport.excludePathFromBackup(absolutePath)),
    );
  }

  Future<void> closeSession(VaultSession session) async {
    _requireHandle(session._handle);
    _statusFrom(await _guard(() => _transport.closeSession(session._handle)));
  }

  Future<void> closeAllSessions() async {
    _statusFrom(await _guard(_transport.closeAllSessions));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.internalFailure);
    } on MissingPluginException {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.platformUnavailable);
    }
  }

  VaultSession _sessionFrom(
    VaultSessionReply reply, {
    bool requiresEnvelope = false,
  }) {
    _throwReplyError(reply.error);
    final handle = reply.sessionHandle;
    final keyGenerationId = reply.keyGenerationId;
    final envelope = reply.vaultKeyEnvelope;
    if (handle == null ||
        handle.isEmpty ||
        keyGenerationId == null ||
        !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(keyGenerationId) ||
        (requiresEnvelope && envelope == null)) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.internalFailure);
    }
    if (envelope != null) {
      _requireBounded(envelope);
    }
    return VaultSession._(handle, keyGenerationId, envelope);
  }

  Uint8List _payloadFrom(PayloadReply reply) {
    _throwReplyError(reply.error);
    final payload = reply.payload;
    if (payload == null) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.internalFailure);
    }
    _requireBounded(payload);
    // Pigeon may expose platform bytes as an unmodifiable typed-data view.
    // Domain/storage consumers must be able to wipe decrypted plaintext.
    return Uint8List.fromList(payload);
  }

  void _statusFrom(StatusReply reply) => _throwReplyError(reply.error);

  void _throwReplyError(KeyBridgeErrorCode? error) {
    if (error != null) {
      throw KeyBridgeFailure(error);
    }
  }

  void _requireHandle(String handle) {
    if (handle.isEmpty || handle.length > 128) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
    }
  }

  void _requireNonEmpty(Uint8List value) {
    if (value.isEmpty) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
    }
    _requireBounded(value);
  }

  void _requireBounded(Uint8List value) {
    if (value.lengthInBytes > _maximumBridgePayloadBytes) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.payloadTooLarge);
    }
  }

  void _requireAuthenticatedData(Uint8List value) {
    if (value.isEmpty || value.lengthInBytes > _maximumAuthenticatedDataBytes) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
    }
  }

  void _requireRecoveryWords(Uint8List value, {required int expectedWords}) {
    if (value.isEmpty || value.lengthInBytes > 512) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
    }
    var words = 1;
    var wordLength = 0;
    for (final byte in value) {
      if (byte == 0x20) {
        if (wordLength == 0 || wordLength > 16) {
          throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
        }
        words += 1;
        wordLength = 0;
      } else if ((byte >= 0x41 && byte <= 0x5a) ||
          (byte >= 0x61 && byte <= 0x7a)) {
        wordLength += 1;
      } else {
        throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
      }
    }
    if (words != expectedWords || wordLength == 0 || wordLength > 16) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.invalidRequest);
    }
  }

  void _wipe(Uint8List value) => value.fillRange(0, value.length, 0);
}

// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';

import 'key_bridge_messages.g.dart';

const int _maximumBridgePayloadBytes = 16 * 1024 * 1024;

/// A secret-free failure exposed by the key bridge facade.
final class KeyBridgeFailure implements Exception {
  const KeyBridgeFailure(this.code);

  final KeyBridgeErrorCode code;

  @override
  String toString() => 'KeyBridgeFailure(${code.name})';
}

/// Opaque capability for native process-local vault key state.
final class VaultSession {
  const VaultSession._(this._handle, this.vaultKeyEnvelope);

  final String _handle;
  final Uint8List? vaultKeyEnvelope;
}

abstract interface class KeyBridgeTransport {
  Future<VaultSessionReply> createVaultKey(CreateVaultKeyRequest request);

  Future<VaultSessionReply> openVaultSession(OpenVaultSessionRequest request);

  Future<PayloadReply> encryptPayload(EncryptPayloadRequest request);

  Future<PayloadReply> decryptPayload(DecryptPayloadRequest request);

  Future<PayloadReply> rewrapVaultKey(RewrapVaultKeyRequest request);

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

  Future<VaultSession> createVaultKey(Uint8List masterPassword) async {
    try {
      _requireNonEmpty(masterPassword);
      final reply = await _guard(
        () => _transport.createVaultKey(
          CreateVaultKeyRequest(masterPassword: masterPassword),
        ),
      );
      return _sessionFrom(reply, requiresEnvelope: true);
    } finally {
      _wipe(masterPassword);
    }
  }

  Future<VaultSession> openVaultSession({
    required Uint8List masterPassword,
    required Uint8List vaultKeyEnvelope,
  }) async {
    try {
      _requireNonEmpty(masterPassword);
      _requireBounded(vaultKeyEnvelope);
      final reply = await _guard(
        () => _transport.openVaultSession(
          OpenVaultSessionRequest(
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
      _requireNonEmpty(authenticatedData);
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
    _requireNonEmpty(authenticatedData);
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
    final envelope = reply.vaultKeyEnvelope;
    if (handle == null ||
        handle.isEmpty ||
        (requiresEnvelope && envelope == null)) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.internalFailure);
    }
    if (envelope != null) {
      _requireBounded(envelope);
    }
    return VaultSession._(handle, envelope);
  }

  Uint8List _payloadFrom(PayloadReply reply) {
    _throwReplyError(reply.error);
    final payload = reply.payload;
    if (payload == null) {
      throw const KeyBridgeFailure(KeyBridgeErrorCode.internalFailure);
    }
    _requireBounded(payload);
    return payload;
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

  void _wipe(Uint8List value) => value.fillRange(0, value.length, 0);
}

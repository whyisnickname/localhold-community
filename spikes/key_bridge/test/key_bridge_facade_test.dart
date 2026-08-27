// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_key_bridge/localhold_key_bridge.dart';
import 'package:localhold_key_bridge/src/key_bridge_messages.g.dart';

void main() {
  group('LocalholdKeyBridge lifecycle', () {
    test('closed session cannot be reused', () async {
      final transport = _LifecycleFakeTransport();
      final bridge = LocalholdKeyBridge(transport: transport);
      final password = Uint8List.fromList([1, 2, 3]);
      final session = await bridge.createVaultKey(password);

      expect(password, everyElement(0));
      await bridge.closeSession(session);

      await expectLater(
        bridge.encryptPayload(
          session: session,
          plaintext: Uint8List.fromList([4]),
          authenticatedData: Uint8List.fromList([5]),
        ),
        throwsA(_failure(KeyBridgeErrorCode.sessionNotFound)),
      );
    });

    test('closeAll invalidates every session', () async {
      final bridge = LocalholdKeyBridge(transport: _LifecycleFakeTransport());
      final first = await bridge.createVaultKey(Uint8List.fromList([1]));
      final second = await bridge.openVaultSession(
        masterPassword: Uint8List.fromList([2]),
        vaultKeyEnvelope: Uint8List.fromList([9]),
      );

      await bridge.closeAllSessions();

      for (final session in [first, second]) {
        await expectLater(
          bridge.decryptPayload(
            session: session,
            encryptedPayload: Uint8List.fromList([3]),
            authenticatedData: Uint8List.fromList([4]),
          ),
          throwsA(_failure(KeyBridgeErrorCode.sessionNotFound)),
        );
      }
    });

    test('closeSession is idempotent', () async {
      final bridge = LocalholdKeyBridge(transport: _LifecycleFakeTransport());
      final session = await bridge.createVaultKey(Uint8List.fromList([1]));

      await bridge.closeSession(session);
      await bridge.closeSession(session);
    });
  });

  group('secret handling and validation', () {
    test('password is overwritten when the host fails', () async {
      final password = Uint8List.fromList([115, 101, 99, 114, 101, 116]);
      final bridge = LocalholdKeyBridge(
        transport: _ThrowingTransport(
          PlatformException(
            code: 'NATIVE_FAILURE',
            message: 'password=secret',
            details: 'secret',
          ),
        ),
      );

      await expectLater(
        bridge.createVaultKey(password),
        throwsA(_failure(KeyBridgeErrorCode.internalFailure)),
      );
      expect(password, everyElement(0));
    });

    test('platform diagnostics are not exposed', () async {
      final bridge = LocalholdKeyBridge(
        transport: _ThrowingTransport(
          PlatformException(code: 'X', message: 'secret-value'),
        ),
      );

      try {
        await bridge.closeAllSessions();
        fail('Expected KeyBridgeFailure');
      } on KeyBridgeFailure catch (error) {
        expect(error.code, KeyBridgeErrorCode.internalFailure);
        expect(error.toString(), isNot(contains('secret-value')));
      }
    });

    test('empty authenticated data is rejected before transport', () async {
      final transport = _LifecycleFakeTransport();
      final bridge = LocalholdKeyBridge(transport: transport);
      final session = await bridge.createVaultKey(Uint8List.fromList([1]));
      final plaintext = Uint8List.fromList([2]);

      await expectLater(
        bridge.encryptPayload(
          session: session,
          plaintext: plaintext,
          authenticatedData: Uint8List(0),
        ),
        throwsA(_failure(KeyBridgeErrorCode.invalidRequest)),
      );
      expect(plaintext, everyElement(0));
    });
  });
}

Matcher _failure(KeyBridgeErrorCode code) =>
    isA<KeyBridgeFailure>().having((failure) => failure.code, 'code', code);

final class _LifecycleFakeTransport implements KeyBridgeTransport {
  final Set<String> _sessions = <String>{};
  var _nextSession = 1;

  @override
  Future<VaultSessionReply> createVaultKey(
    CreateVaultKeyRequest request,
  ) async {
    final handle = 'test-session-${_nextSession++}';
    _sessions.add(handle);
    return VaultSessionReply(
      sessionHandle: handle,
      vaultKeyEnvelope: Uint8List.fromList([1]),
    );
  }

  @override
  Future<VaultSessionReply> openVaultSession(
    OpenVaultSessionRequest request,
  ) async {
    final handle = 'test-session-${_nextSession++}';
    _sessions.add(handle);
    return VaultSessionReply(sessionHandle: handle);
  }

  @override
  Future<PayloadReply> encryptPayload(EncryptPayloadRequest request) async =>
      _sessions.contains(request.sessionHandle)
      ? PayloadReply(payload: Uint8List.fromList([1]))
      : PayloadReply(error: KeyBridgeErrorCode.sessionNotFound);

  @override
  Future<PayloadReply> decryptPayload(DecryptPayloadRequest request) async =>
      _sessions.contains(request.sessionHandle)
      ? PayloadReply(payload: Uint8List.fromList([1]))
      : PayloadReply(error: KeyBridgeErrorCode.sessionNotFound);

  @override
  Future<PayloadReply> rewrapVaultKey(RewrapVaultKeyRequest request) async =>
      _sessions.contains(request.sessionHandle)
      ? PayloadReply(payload: Uint8List.fromList([1]))
      : PayloadReply(error: KeyBridgeErrorCode.sessionNotFound);

  @override
  Future<StatusReply> closeSession(String sessionHandle) async {
    _sessions.remove(sessionHandle);
    return StatusReply();
  }

  @override
  Future<StatusReply> closeAllSessions() async {
    _sessions.clear();
    return StatusReply();
  }
}

final class _ThrowingTransport implements KeyBridgeTransport {
  _ThrowingTransport(this.error);

  final Object error;

  Never _throw() => throw error;

  @override
  Future<StatusReply> closeAllSessions() async => _throw();

  @override
  Future<StatusReply> closeSession(String sessionHandle) async => _throw();

  @override
  Future<VaultSessionReply> createVaultKey(
    CreateVaultKeyRequest request,
  ) async => _throw();

  @override
  Future<PayloadReply> decryptPayload(DecryptPayloadRequest request) async =>
      _throw();

  @override
  Future<PayloadReply> encryptPayload(EncryptPayloadRequest request) async =>
      _throw();

  @override
  Future<VaultSessionReply> openVaultSession(
    OpenVaultSessionRequest request,
  ) async => _throw();

  @override
  Future<PayloadReply> rewrapVaultKey(RewrapVaultKeyRequest request) async =>
      _throw();
}

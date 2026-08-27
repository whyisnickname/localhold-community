// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_native/localhold_key_bridge.dart';
import 'package:localhold_vault_native/src/key_bridge_messages.g.dart';

const _vaultId = 'AAAAAAAAAAAAAAAAAAAAAA';
const _keyGenerationId = 'BBBBBBBBBBBBBBBBBBBBBB';

void main() {
  group('LocalholdKeyBridge lifecycle', () {
    test('closed session cannot be reused', () async {
      final transport = _LifecycleFakeTransport();
      final bridge = LocalholdKeyBridge(transport: transport);
      final password = Uint8List.fromList([1, 2, 3]);
      final session = await bridge.createVaultKey(
        vaultId: _vaultId,
        masterPassword: password,
      );

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
      final first = await bridge.createVaultKey(
        vaultId: _vaultId,
        masterPassword: Uint8List.fromList([1]),
      );
      final second = await bridge.openVaultSession(
        vaultId: _vaultId,
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
  });

  group('secret handling and validation', () {
    test('password is overwritten when the host fails', () async {
      final password = Uint8List.fromList([115, 101, 99, 114, 101, 116]);
      final bridge = LocalholdKeyBridge(
        transport: _LifecycleFakeTransport(
          failure: PlatformException(
            code: 'NATIVE_FAILURE',
            message: 'password=secret',
            details: 'secret',
          ),
        ),
      );

      await expectLater(
        bridge.createVaultKey(vaultId: _vaultId, masterPassword: password),
        throwsA(_failure(KeyBridgeErrorCode.internalFailure)),
      );
      expect(password, everyElement(0));
    });

    test('platform diagnostics are not exposed', () async {
      final bridge = LocalholdKeyBridge(
        transport: _LifecycleFakeTransport(
          failure: PlatformException(code: 'X', message: 'secret-value'),
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

    test('recovery input is validated and overwritten', () async {
      final input = Uint8List.fromList('wrong phrase'.codeUnits);
      final bridge = LocalholdKeyBridge(transport: _LifecycleFakeTransport());
      await expectLater(
        bridge.openVaultWithRecovery(
          vaultId: _vaultId,
          recoveryPhraseUtf8: input,
          recoveryKeyEnvelope: Uint8List.fromList([1]),
        ),
        throwsA(_failure(KeyBridgeErrorCode.invalidRequest)),
      );
      expect(input, everyElement(0));
    });

    test('oversized authenticated data is rejected before transport', () async {
      final bridge = LocalholdKeyBridge(transport: _LifecycleFakeTransport());
      final session = await bridge.createVaultKey(
        vaultId: _vaultId,
        masterPassword: Uint8List.fromList([1]),
      );
      final plaintext = Uint8List.fromList([2]);
      await expectLater(
        bridge.encryptPayload(
          session: session,
          plaintext: plaintext,
          authenticatedData: Uint8List(4097),
        ),
        throwsA(_failure(KeyBridgeErrorCode.invalidRequest)),
      );
      expect(plaintext, everyElement(0));
    });

    test('platform payload is copied into a mutable wipeable buffer', () async {
      final bridge = LocalholdKeyBridge(
        transport: _LifecycleFakeTransport(unmodifiablePayload: true),
      );
      final session = await bridge.createVaultKey(
        vaultId: _vaultId,
        masterPassword: Uint8List.fromList([1]),
      );

      final plaintext = await bridge.decryptPayload(
        session: session,
        encryptedPayload: Uint8List.fromList([2]),
        authenticatedData: Uint8List.fromList([3]),
      );
      plaintext.fillRange(0, plaintext.length, 0);

      expect(plaintext, everyElement(0));
    });
  });
}

Matcher _failure(KeyBridgeErrorCode code) =>
    isA<KeyBridgeFailure>().having((failure) => failure.code, 'code', code);

final class _LifecycleFakeTransport implements KeyBridgeTransport {
  _LifecycleFakeTransport({this.failure, this.unmodifiablePayload = false});

  final Object? failure;
  final bool unmodifiablePayload;
  final Set<String> _sessions = <String>{};
  var _nextSession = 1;

  void _check() {
    if (failure != null) throw failure!;
  }

  VaultSessionReply _session({bool envelope = false}) {
    final handle = 'test-session-${_nextSession++}';
    _sessions.add(handle);
    return VaultSessionReply(
      sessionHandle: handle,
      keyGenerationId: _keyGenerationId,
      vaultKeyEnvelope: envelope ? Uint8List.fromList([1]) : null,
    );
  }

  PayloadReply _payload(String handle) => _sessions.contains(handle)
      ? PayloadReply(
          payload: unmodifiablePayload
              ? Uint8List.fromList([1]).asUnmodifiableView()
              : Uint8List.fromList([1]),
        )
      : PayloadReply(error: KeyBridgeErrorCode.sessionNotFound);

  @override
  Future<VaultSessionReply> createVaultKey(
    CreateVaultKeyRequest request,
  ) async {
    _check();
    return _session(envelope: true);
  }

  @override
  Future<VaultSessionReply> openVaultSession(
    OpenVaultSessionRequest request,
  ) async {
    _check();
    return _session();
  }

  @override
  Future<PayloadReply> encryptPayload(EncryptPayloadRequest request) async {
    _check();
    return _payload(request.sessionHandle);
  }

  @override
  Future<PayloadReply> decryptPayload(DecryptPayloadRequest request) async {
    _check();
    return _payload(request.sessionHandle);
  }

  @override
  Future<PayloadReply> rewrapVaultKey(RewrapVaultKeyRequest request) async {
    _check();
    return _payload(request.sessionHandle);
  }

  @override
  Future<RecoveryCeremonyReply> beginRecoveryKey(String sessionHandle) async {
    _check();
    return RecoveryCeremonyReply(
      ceremonyHandle: 'ceremony',
      challengePositions: const [1, 7, 13, 24],
    );
  }

  @override
  Future<StatusReply> presentRecoveryKey(String ceremonyHandle) async {
    _check();
    return StatusReply();
  }

  @override
  Future<PayloadReply> confirmRecoveryKey(
    ConfirmRecoveryKeyRequest request,
  ) async {
    _check();
    return PayloadReply(payload: Uint8List.fromList([1]));
  }

  @override
  Future<VaultSessionReply> openVaultWithRecovery(
    OpenVaultWithRecoveryRequest request,
  ) async {
    _check();
    return _session();
  }

  @override
  Future<StatusReply> cancelRecoveryKey(String ceremonyHandle) async {
    _check();
    return StatusReply();
  }

  @override
  Future<StatusReply> setVaultPrivacyActive(bool active) async {
    _check();
    return StatusReply();
  }

  @override
  Future<StatusReply> copySensitiveClipboard(
    SensitiveClipboardRequest request,
  ) async {
    _check();
    return StatusReply();
  }

  @override
  Future<StatusReply> clearSensitiveClipboard() async {
    _check();
    return StatusReply();
  }

  @override
  Future<StatusReply> enableBiometric(String sessionHandle) async {
    _check();
    return StatusReply();
  }

  @override
  Future<VaultSessionReply> openVaultWithBiometric(String vaultId) async {
    _check();
    return _session();
  }

  @override
  Future<StatusReply> disableBiometric(String sessionHandle) async {
    _check();
    return StatusReply();
  }

  @override
  Future<BiometricStatusReply> biometricStatus(String vaultId) async {
    _check();
    return BiometricStatusReply(configured: false);
  }

  @override
  Future<StatusReply> excludePathFromBackup(String absolutePath) async {
    _check();
    return StatusReply();
  }

  @override
  Future<StatusReply> closeSession(String sessionHandle) async {
    _check();
    _sessions.remove(sessionHandle);
    return StatusReply();
  }

  @override
  Future<StatusReply> closeAllSessions() async {
    _check();
    _sessions.clear();
    return StatusReply();
  }
}

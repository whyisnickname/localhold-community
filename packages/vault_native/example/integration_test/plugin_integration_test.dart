// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localhold_vault_native/localhold_key_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native create, encrypt, decrypt and close lifecycle', (
    tester,
  ) async {
    final bridge = LocalholdKeyBridge();
    await expectLater(
      bridge.createVaultKey(
        vaultId: 'CCCCCCCCCCCCCCCCCCCCCC',
        masterPassword: Uint8List.fromList('too-short'.codeUnits),
      ),
      throwsA(
        isA<KeyBridgeFailure>().having(
          (error) => error.code,
          'code',
          KeyBridgeErrorCode.invalidRequest,
        ),
      ),
    );
    final plaintext = Uint8List.fromList('stage4-local-only'.codeUnits);
    final expected = Uint8List.fromList(plaintext);
    final aad = Uint8List.fromList('stage4-aad'.codeUnits);
    final session = await bridge.createVaultKey(
      vaultId: 'AAAAAAAAAAAAAAAAAAAAAA',
      masterPassword: Uint8List.fromList(
        'correct horse battery staple'.codeUnits,
      ),
    );
    addTearDown(bridge.closeAllSessions);
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION created');

    final envelope = await bridge.encryptPayload(
      session: session,
      plaintext: plaintext,
      authenticatedData: aad,
    );
    expect(plaintext, everyElement(0));
    final restored = await bridge.decryptPayload(
      session: session,
      encryptedPayload: envelope,
      authenticatedData: aad,
    );
    expect(restored, expected);
    restored.fillRange(0, restored.length, 0);
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION base_round_trip');

    final reservedEnvelopes = <Uint8List>[];
    for (var index = 0; index < 128; index++) {
      reservedEnvelopes.add(
        await bridge.encryptPayload(
          session: session,
          plaintext: Uint8List.fromList('parallel-$index'.codeUnits),
          authenticatedData: Uint8List.fromList('stage4-nonce-aad'.codeUnits),
        ),
      );
    }
    final nonces = reservedEnvelopes
        .map((value) => value.sublist(21, 33).join(','))
        .toSet();
    expect(nonces, hasLength(reservedEnvelopes.length));
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION unique_nonces=128');

    await bridge.setVaultPrivacyActive(true);
    await bridge.setVaultPrivacyActive(false);
    await bridge.copySensitiveClipboard(
      utf8Value: Uint8List.fromList('localhold-test-clipboard'.codeUnits),
      expirySeconds: 15,
    );
    expect(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      'localhold-test-clipboard',
    );
    await Clipboard.setData(
      const ClipboardData(text: 'external-owner-content'),
    );
    await bridge.clearSensitiveClipboard();
    expect(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      'external-owner-content',
    );
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION privacy_and_clipboard');

    await expectLater(
      bridge.decryptPayload(
        session: session,
        encryptedPayload: envelope,
        authenticatedData: Uint8List.fromList('wrong-aad'.codeUnits),
      ),
      throwsA(
        isA<KeyBridgeFailure>().having(
          (error) => error.code,
          'code',
          KeyBridgeErrorCode.integrityFailure,
        ),
      ),
    );
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION tamper_rejected');
    final tampered = Uint8List.fromList(envelope)..last ^= 0xff;
    await expectLater(
      bridge.decryptPayload(
        session: session,
        encryptedPayload: tampered,
        authenticatedData: aad,
      ),
      throwsA(
        isA<KeyBridgeFailure>().having(
          (error) => error.code,
          'code',
          KeyBridgeErrorCode.integrityFailure,
        ),
      ),
    );

    final newMasterEnvelope = await bridge.rewrapVaultKey(
      session: session,
      newMasterPassword: Uint8List.fromList(
        'new correct horse battery staple'.codeUnits,
      ),
    );
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION rewrapped');
    final reopened = await bridge.openVaultSession(
      vaultId: 'AAAAAAAAAAAAAAAAAAAAAA',
      masterPassword: Uint8List.fromList(
        'new correct horse battery staple'.codeUnits,
      ),
      vaultKeyEnvelope: newMasterEnvelope,
    );
    final reopenedPlaintext = Uint8List.fromList('rewrapped'.codeUnits);
    final reopenedExpected = Uint8List.fromList(reopenedPlaintext);
    final reopenedEnvelope = await bridge.encryptPayload(
      session: reopened,
      plaintext: reopenedPlaintext,
      authenticatedData: aad,
    );
    final reopenedResult = await bridge.decryptPayload(
      session: reopened,
      encryptedPayload: reopenedEnvelope,
      authenticatedData: aad,
    );
    expect(reopenedResult, reopenedExpected);
    reopenedResult.fillRange(0, reopenedResult.length, 0);
    await bridge.closeSession(reopened);
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION reopened_and_closed');

    await bridge.closeSession(session);
    await expectLater(
      bridge.decryptPayload(
        session: session,
        encryptedPayload: envelope,
        authenticatedData: aad,
      ),
      throwsA(
        isA<KeyBridgeFailure>().having(
          (error) => error.code,
          'code',
          KeyBridgeErrorCode.sessionNotFound,
        ),
      ),
    );
    // ignore: avoid_print
    print('STAGE4_ANDROID_INTEGRATION stale_session_rejected');
  });
}

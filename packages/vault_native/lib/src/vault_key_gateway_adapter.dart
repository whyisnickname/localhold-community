// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'key_bridge.dart';
import 'key_bridge_messages.g.dart';

abstract interface class VaultEnvelopeStore {
  Future<Uint8List?> readMaster(VaultId vaultId);

  Future<void> createMaster(VaultId vaultId, Uint8List envelope);

  Future<void> replaceMaster(VaultId vaultId, Uint8List envelope);

  Future<Uint8List?> readRecovery(VaultId vaultId);

  Future<void> replaceRecovery(VaultId vaultId, Uint8List envelope);
}

final class NativeVaultKeyGateway implements VaultKeyGateway {
  NativeVaultKeyGateway({required this._bridge, required this._envelopeStore});

  final LocalholdKeyBridge _bridge;
  final VaultEnvelopeStore _envelopeStore;
  final Map<String, _NativeVaultSessionBinding> _sessions = {};
  final Map<RecoveryCeremony, VaultId> _recoveryVaults = {};

  @override
  Future<VaultSessionRef> createVault({
    required VaultId vaultId,
    required Uint8List masterPassword,
  }) async {
    final session = await _mapFailure(
      () => _bridge.createVaultKey(
        vaultId: vaultId.value,
        masterPassword: masterPassword,
      ),
    );
    final envelope = session.vaultKeyEnvelope;
    if (envelope == null) {
      await _bridge.closeSession(session);
      throw const VaultFailure(VaultFailureCode.internalFailure);
    }
    try {
      await _envelopeStore.createMaster(vaultId, envelope);
      return _remember(vaultId, session);
    } catch (_) {
      await _bridge.closeSession(session);
      rethrow;
    }
  }

  @override
  Future<VaultSessionRef> openVault({
    required VaultId vaultId,
    required Uint8List masterPassword,
  }) async {
    final envelope = await _envelopeStore.readMaster(vaultId);
    if (envelope == null) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    final session = await _mapFailure(
      () => _bridge.openVaultSession(
        vaultId: vaultId.value,
        masterPassword: masterPassword,
        vaultKeyEnvelope: envelope,
      ),
    );
    return _remember(vaultId, session);
  }

  Future<RecoveryCeremony> beginRecovery(VaultSessionRef session) async {
    final binding = _requireBinding(session);
    final ceremony = await _mapFailure(
      () => _bridge.beginRecoveryKey(binding.session),
    );
    _recoveryVaults[ceremony] = binding.vaultId;
    return ceremony;
  }

  Future<void> enableBiometric(VaultSessionRef session) =>
      _mapFailure(() => _bridge.enableBiometric(_requireNative(session)));

  Future<VaultSessionRef> openWithBiometric(VaultId vaultId) async {
    final native = await _mapFailure(
      () => _bridge.openVaultWithBiometric(vaultId.value),
    );
    return _remember(vaultId, native);
  }

  Future<void> disableBiometric(VaultSessionRef session) =>
      _mapFailure(() => _bridge.disableBiometric(_requireNative(session)));

  Future<BiometricStatus> biometricStatus(VaultId vaultId) =>
      _mapFailure(() => _bridge.biometricStatus(vaultId.value));

  Future<void> changeMasterPassword({
    required VaultId vaultId,
    required VaultSessionRef session,
    required Uint8List newMasterPassword,
  }) async {
    final binding = _requireBinding(session);
    if (binding.vaultId != vaultId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final envelope = await _mapFailure(
      () => _bridge.rewrapVaultKey(
        session: binding.session,
        newMasterPassword: newMasterPassword,
      ),
    );
    await _envelopeStore.replaceMaster(vaultId, envelope);
  }

  Future<void> presentRecovery(RecoveryCeremony ceremony) =>
      _mapFailure(() => _bridge.presentRecoveryKey(ceremony));

  Future<void> confirmRecovery({
    required VaultId vaultId,
    required RecoveryCeremony ceremony,
    required Uint8List challengeWordsUtf8,
  }) async {
    if (_recoveryVaults[ceremony] != vaultId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final envelope = await _mapFailure(
      () => _bridge.confirmRecoveryKey(
        ceremony: ceremony,
        challengeWordsUtf8: challengeWordsUtf8,
      ),
    );
    _recoveryVaults.remove(ceremony);
    await _envelopeStore.replaceRecovery(vaultId, envelope);
  }

  Future<void> cancelRecovery(RecoveryCeremony ceremony) async {
    try {
      await _mapFailure(() => _bridge.cancelRecoveryKey(ceremony));
    } finally {
      _recoveryVaults.remove(ceremony);
    }
  }

  /// Recovery never opens ordinary use directly: it atomically establishes a
  /// new master wrapper before returning the session to the coordinator.
  Future<VaultSessionRef> recoverAndReplaceMaster({
    required VaultId vaultId,
    required Uint8List recoveryPhraseUtf8,
    required Uint8List newMasterPassword,
  }) async {
    final recoveryEnvelope = await _envelopeStore.readRecovery(vaultId);
    if (recoveryEnvelope == null) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    final native = await _mapFailure(
      () => _bridge.openVaultWithRecovery(
        vaultId: vaultId.value,
        recoveryPhraseUtf8: recoveryPhraseUtf8,
        recoveryKeyEnvelope: recoveryEnvelope,
      ),
    );
    try {
      final newEnvelope = await _mapFailure(
        () => _bridge.rewrapVaultKey(
          session: native,
          newMasterPassword: newMasterPassword,
        ),
      );
      await _envelopeStore.replaceMaster(vaultId, newEnvelope);
      return _remember(vaultId, native);
    } catch (_) {
      await _bridge.closeSession(native);
      rethrow;
    }
  }

  PayloadCipher payloadCipher(VaultSessionRef session) {
    final binding = _requireBinding(session);
    return NativeSessionPayloadCipher(
      bridge: _bridge,
      session: binding.session,
      vaultId: binding.vaultId,
    );
  }

  @override
  Future<void> close(VaultSessionRef session) async {
    final binding = _sessions.remove(session.value);
    if (binding != null) {
      await _mapFailure(() => _bridge.closeSession(binding.session));
    }
  }

  @override
  Future<void> closeAll() async {
    _sessions.clear();
    _recoveryVaults.clear();
    await _mapFailure(_bridge.closeAllSessions);
  }

  VaultSessionRef _remember(VaultId vaultId, VaultSession session) {
    final reference = VaultSessionRef.fromOpaque(session.opaqueReference);
    _sessions[reference.value] = _NativeVaultSessionBinding(vaultId, session);
    return reference;
  }

  _NativeVaultSessionBinding _requireBinding(VaultSessionRef session) =>
      _sessions[session.value] ??
      (throw const VaultFailure(VaultFailureCode.sessionNotFound));

  VaultSession _requireNative(VaultSessionRef session) =>
      _requireBinding(session).session;
}

final class _NativeVaultSessionBinding {
  const _NativeVaultSessionBinding(this.vaultId, this.session);

  final VaultId vaultId;
  final VaultSession session;
}

final class NativeSessionPayloadCipher implements PayloadCipher {
  const NativeSessionPayloadCipher({
    required this._bridge,
    required this._session,
    required this._vaultId,
  });

  final LocalholdKeyBridge _bridge;
  final VaultSession _session;
  final VaultId _vaultId;

  @override
  String get vaultId => _vaultId.value;

  @override
  String get keyGenerationId => _session.keyGenerationId;

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) => _mapFailure(
    () => _bridge.decryptPayload(
      session: _session,
      encryptedPayload: envelope,
      authenticatedData: authenticatedData,
    ),
  );

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) => _mapFailure(
    () => _bridge.encryptPayload(
      session: _session,
      plaintext: plaintext,
      authenticatedData: authenticatedData,
    ),
  );
}

final class NativeVaultPrivacyGateway implements VaultPrivacyGateway {
  const NativeVaultPrivacyGateway(this._bridge);

  final LocalholdKeyBridge _bridge;

  @override
  Future<void> clearSensitiveClipboard() =>
      _mapFailure(_bridge.clearSensitiveClipboard);

  @override
  Future<void> copySensitive({
    required Uint8List utf8Value,
    required ClipboardExpiry expiry,
  }) => _mapFailure(
    () => _bridge.copySensitiveClipboard(
      utf8Value: utf8Value,
      expirySeconds: expiry.seconds,
    ),
  );

  @override
  Future<void> setVaultPrivacyActive(bool active) =>
      _mapFailure(() => _bridge.setVaultPrivacyActive(active));
}

final class NativeBackupExclusionGateway implements BackupExclusionGateway {
  const NativeBackupExclusionGateway(this._bridge);

  final LocalholdKeyBridge _bridge;

  @override
  Future<void> excludeAbsolutePath(String absolutePath) =>
      _mapFailure(() => _bridge.excludePathFromBackup(absolutePath));
}

Future<T> _mapFailure<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on KeyBridgeFailure catch (failure) {
    throw VaultFailure(switch (failure.code) {
      KeyBridgeErrorCode.invalidRequest => VaultFailureCode.invalidInput,
      KeyBridgeErrorCode.invalidCredentials =>
        VaultFailureCode.invalidCredentials,
      KeyBridgeErrorCode.unsupportedVersion =>
        VaultFailureCode.unsupportedVersion,
      KeyBridgeErrorCode.sessionNotFound => VaultFailureCode.sessionNotFound,
      KeyBridgeErrorCode.sessionLocked => VaultFailureCode.sessionLocked,
      KeyBridgeErrorCode.reauthenticationRequired =>
        VaultFailureCode.reauthenticationRequired,
      KeyBridgeErrorCode.integrityFailure => VaultFailureCode.integrityFailure,
      KeyBridgeErrorCode.payloadTooLarge => VaultFailureCode.payloadTooLarge,
      KeyBridgeErrorCode.platformUnavailable =>
        VaultFailureCode.platformUnavailable,
      KeyBridgeErrorCode.biometricUnavailable =>
        VaultFailureCode.biometricUnavailable,
      KeyBridgeErrorCode.biometricInvalidated =>
        VaultFailureCode.biometricInvalidated,
      KeyBridgeErrorCode.internalFailure => VaultFailureCode.internalFailure,
    });
  }
}

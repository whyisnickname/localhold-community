// SPDX-License-Identifier: MPL-2.0

package dev.localhold.localhold_key_bridge

import io.flutter.embedding.engine.plugins.FlutterPlugin

private const val LOCALHOLD_STAGE2_SPIKE_DO_NOT_SHIP = true

/** Fail-closed Stage 2 adapter with no cryptography or key state. */
class LocalholdKeyBridgePlugin : FlutterPlugin, KeyBridgeHostApi {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        check(LOCALHOLD_STAGE2_SPIKE_DO_NOT_SHIP)
        KeyBridgeHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        KeyBridgeHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun createVaultKey(request: CreateVaultKeyRequest): VaultSessionReply =
        VaultSessionReply(error = KeyBridgeErrorCode.NOT_IMPLEMENTED)

    override fun openVaultSession(request: OpenVaultSessionRequest): VaultSessionReply =
        VaultSessionReply(error = KeyBridgeErrorCode.NOT_IMPLEMENTED)

    override fun encryptPayload(request: EncryptPayloadRequest): PayloadReply =
        PayloadReply(error = KeyBridgeErrorCode.NOT_IMPLEMENTED)

    override fun decryptPayload(request: DecryptPayloadRequest): PayloadReply =
        PayloadReply(error = KeyBridgeErrorCode.NOT_IMPLEMENTED)

    override fun rewrapVaultKey(request: RewrapVaultKeyRequest): PayloadReply =
        PayloadReply(error = KeyBridgeErrorCode.NOT_IMPLEMENTED)

    override fun closeSession(sessionHandle: String): StatusReply =
        StatusReply(error = KeyBridgeErrorCode.NOT_IMPLEMENTED)

    override fun closeAllSessions(): StatusReply =
        StatusReply(error = KeyBridgeErrorCode.NOT_IMPLEMENTED)
}

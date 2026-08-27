// SPDX-License-Identifier: MPL-2.0

package dev.localhold.localhold_key_bridge

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class LocalholdKeyBridgePluginTest {
    private val plugin = LocalholdKeyBridgePlugin()

    @Test
    fun everySecurityOperationFailsClosed() {
        val create = plugin.createVaultKey(CreateVaultKeyRequest(byteArrayOf(1)))
        val encrypt =
            plugin.encryptPayload(
                EncryptPayloadRequest("opaque", byteArrayOf(2), byteArrayOf(3)),
            )

        assertEquals(KeyBridgeErrorCode.NOT_IMPLEMENTED, create.error)
        assertNull(create.sessionHandle)
        assertNull(create.vaultKeyEnvelope)
        assertEquals(KeyBridgeErrorCode.NOT_IMPLEMENTED, encrypt.error)
        assertNull(encrypt.payload)
    }
}

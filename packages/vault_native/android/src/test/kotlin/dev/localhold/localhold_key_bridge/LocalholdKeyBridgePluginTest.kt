// SPDX-License-Identifier: MPL-2.0

package dev.localhold.localhold_key_bridge

import org.junit.jupiter.api.Test
import java.io.File
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class LocalholdKeyBridgePluginTest {
    @Test
    fun productionRegistrationHasNoDiagnosticFallback() {
        val source = File(
            "src/main/kotlin/dev/localhold/localhold_key_bridge/" +
                "LocalholdKeyBridgePlugin.kt",
        ).readText()
        assertTrue(source.contains("NativeVaultCryptoService"))
        assertTrue(source.contains("Intent.ACTION_SCREEN_OFF"))
        assertTrue(source.contains("BACKGROUND_LOCK_MILLIS"))
        assertFalse(source.contains("NOT_IMPLEMENTED"))
        assertFalse(source.contains("HttpClient"))
    }
}

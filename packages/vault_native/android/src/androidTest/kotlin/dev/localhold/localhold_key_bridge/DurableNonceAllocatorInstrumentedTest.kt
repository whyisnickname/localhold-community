// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.security.SecureRandom
import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DurableNonceAllocatorInstrumentedTest {
    @Test
    fun concurrentReservationsAndProcessRestartNeverRepeatNonce() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val preferences = context.getSharedPreferences(
            "stage4_nonce_allocator_instrumented_test",
            0,
        )
        assertTrue(preferences.edit().clear().commit())
        val generation = ByteArray(16) { index -> (index + 1).toByte() }
        val allocator = DurableNonceAllocator(preferences, SecureRandom())
        allocator.initialize(generation)
        val values = Collections.synchronizedSet(mutableSetOf<String>())
        val workers = Executors.newFixedThreadPool(8)
        try {
            val futures = (0 until 8).map {
                workers.submit {
                    repeat(128) {
                        values += allocator.reserve(generation).toHex()
                    }
                }
            }
            futures.forEach { future -> future.get(30, TimeUnit.SECONDS) }
        } finally {
            workers.shutdownNow()
        }
        assertEquals(1024, values.size)

        val afterRestart = DurableNonceAllocator(preferences, SecureRandom())
            .reserve(generation)
            .toHex()
        assertFalse(values.contains(afterRestart))
        assertTrue(preferences.edit().clear().commit())
    }

    private fun ByteArray.toHex(): String =
        joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }
}

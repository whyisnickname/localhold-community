// SPDX-License-Identifier: MPL-2.0
package dev.localhold.argon2.calibration

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.time.Instant
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ArgonCalibrationInstrumentedTest {
    private val password = "localhold-stage2-synthetic-password".encodeToByteArray()
    private val salt = ByteArray(16) { index -> (index + 1).toByte() }

    @Test
    fun candidateGridSmokeTest() {
        try {
            for (memoryKib in listOf(65_536, 98_304, 131_072)) {
                for (operations in listOf(2L, 3L, 4L)) {
                    val result = runNative(memoryKib, operations, 1)
                    assertTrue(result.getBoolean("ok"))
                    println("LOCALHOLD_ARGON2_SMOKE $result")
                }
            }
        } finally {
            clearSyntheticInputs()
        }
    }

    @Test
    fun localholdUtf8VectorsMatchWithoutNormalization() {
        val vectors = listOf(
            "ascii" to (
                "6c6f63616c686f6c642d7374616765322d73796e7468657469632d70617373776f7264" to
                    "39bf18e5fdc7044a024f188e65b6ab5b8f65a607748ee5dd0ae57e5521a8ee54"
                ),
            "cyrillic" to (
                "d09fd0b0d180d0bed0bbd18c" to
                    "7f562246443ab55f21f3fa0aa68a6ce1b9593ea4ddf2aaa8eaf8ce0020afa2da"
                ),
            "emoji" to (
                "f09f94902070617373776f7264" to
                    "387ddd614859bacb69ea6daf05e8b8fb18418fa5d5e24c6ab7b5f55467e48526"
                ),
            "nfc" to (
                "c3a9" to
                    "d1b586a8de64f7e17a2ce6d65549c4e79f117c2035ed6dedd508cbaa2134e0cb"
                ),
            "nfd" to (
                "65cc81" to
                    "ad6dd9d760c3f4a4fa9a33e67d13e800a4536ac977f2bb02ede98cd9d1792162"
                ),
        )
        val vectorSalt = ByteArray(16) { index -> (index + 1).toByte() }
        try {
            vectors.forEach { (id, value) ->
                val vectorPassword = value.first.hexBytes()
                try {
                    val result = JSONObject(
                        NativeArgon2Calibration.runSynthetic(
                            password = vectorPassword,
                            salt = vectorSalt,
                            memoryKib = 65_536,
                            operations = 3,
                            samples = 1,
                        ),
                    )
                    assertTrue("$id derivation failed", result.getBoolean("ok"))
                    assertEquals("$id output", value.second, result.getString("output_sha256"))
                } finally {
                    vectorPassword.fill(0)
                }
            }
            assertFalse("NFC/NFD must remain distinct", vectors[3].second.second == vectors[4].second.second)
        } finally {
            vectorSalt.fill(0)
        }
    }

    @Test
    fun selectedProfileProducesSchemaReadyEvidence() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val arguments = InstrumentationRegistry.getArguments()
        val context = instrumentation.targetContext
        val memoryKib = arguments.getString("memoryKib")?.toInt() ?: 65_536
        val operations = arguments.getString("operations")?.toLong() ?: 3L
        val revision = arguments.getString("buildRevision") ?: "0000000"
        require(Regex("^[0-9a-fA-F]{7,64}$").matches(revision))

        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val memoryBefore = ActivityManager.MemoryInfo().also(activityManager::getMemoryInfo)
        val thermalBefore = thermalStatus(powerManager)

        try {
            repeat(5) { assertTrue(runNative(memoryKib, operations, 1).getBoolean("ok")) }
            val measured = runNative(memoryKib, operations, 30)
            assertTrue(measured.getBoolean("ok"))
            val expectedHash = measured.getString("output_sha256")

            var stressSuccessfulRuns = 0
            repeat(20) {
                val stress = runNative(memoryKib, operations, 1)
                assertTrue(stress.getBoolean("ok"))
                assertEquals(expectedHash, stress.getString("output_sha256"))
                stressSuccessfulRuns += 1
            }

            val memoryAfter = ActivityManager.MemoryInfo().also(activityManager::getMemoryInfo)
            val samplesMs = JSONArray()
            val samplesNs = measured.getJSONArray("samples_ns")
            for (index in 0 until samplesNs.length()) {
                samplesMs.put(samplesNs.getLong(index).toDouble() / 1_000_000.0)
            }

            val evidence = JSONObject()
                .put("schema_version", 1)
                .put("run_id", UUID.randomUUID().toString())
                .put("recorded_at", Instant.now().toString())
                .put("platform", "android")
                .put("physical_device", isPhysicalDevice())
                .put("device", JSONObject()
                    .put("manufacturer", Build.MANUFACTURER.ifBlank { "unknown" })
                    .put("model", Build.MODEL.ifBlank { "unknown" })
                    .put("os_version", Build.VERSION.RELEASE.ifBlank { Build.VERSION.SDK_INT.toString() })
                    .put("abi", Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown")
                    .put("ram_mib", memoryAfter.totalMem / (1024L * 1024L)))
                .put("build", JSONObject()
                    .put("revision", revision)
                    .put("mode", "release"))
                .put("library", JSONObject()
                    .put("name", "libsodium")
                    .put("version", "1.0.21")
                    .put("source_sha256", LIBSODIUM_SOURCE_SHA256))
                .put("profile", JSONObject()
                    .put("algorithm", "argon2id")
                    .put("version", 19)
                    .put("memory_kib", memoryKib)
                    .put("operations", operations)
                    .put("parallelism", 1)
                    .put("salt_bytes", 16)
                    .put("output_bytes", 32))
                .put("timing", JSONObject()
                    .put("warmup_count", 5)
                    .put("samples_ms", samplesMs)
                    .put("stress_successful_runs", stressSuccessfulRuns))
                .put("safety", JSONObject()
                    .put("oom", false)
                    .put("crash", false)
                    .put("anr", false)
                    .put("safe_memory_pressure", !memoryBefore.lowMemory && !memoryAfter.lowMemory)
                    .put("battery_percent", batteryPercent(context))
                    .put("power_saver", powerManager.isPowerSaveMode)
                    .put("thermal_before", thermalBefore)
                    .put("thermal_after", thermalStatus(powerManager))
                    .put("peak_rss_delta_mib", JSONObject.NULL))
                .put("vector", JSONObject()
                    .put("id", "localhold-argon2id-synthetic-v1")
                    .put("output_sha256", expectedHash))

            println("LOCALHOLD_ARGON2_EVIDENCE $evidence")
            assertEquals(30, samplesMs.length())
            assertEquals(20, stressSuccessfulRuns)
        } finally {
            clearSyntheticInputs()
        }
    }

    @Test
    fun unsafeParametersFailClosed() {
        val validPassword = "localhold-stage2-synthetic-password".encodeToByteArray()
        val validSalt = ByteArray(16) { index -> (index + 1).toByte() }
        try {
            assertInvalid(ByteArray(0), validSalt, 65_536, 3, 1)
            assertInvalid(ByteArray(1_025) { 0x41 }, validSalt, 65_536, 3, 1)
            assertInvalid(validPassword, ByteArray(15), 65_536, 3, 1)
            assertInvalid(validPassword, validSalt, 32_768, 3, 1)
            assertInvalid(validPassword, validSalt, 65_536, 1, 1)
            assertInvalid(validPassword, validSalt, 65_536, 3, 0)
            assertInvalid(validPassword, validSalt, 65_536, 3, 51)

            val expected = runNative(65_536, 3, 1)
            val wrongPassword = "localhold-stage2-synthetic-passw0rd".encodeToByteArray()
            try {
                val wrong = JSONObject(
                    NativeArgon2Calibration.runSynthetic(
                        password = wrongPassword,
                        salt = validSalt,
                        memoryKib = 65_536,
                        operations = 3,
                        samples = 1,
                    ),
                )
                assertTrue(wrong.getBoolean("ok"))
                assertFalse(expected.getString("output_sha256") == wrong.getString("output_sha256"))
            } finally {
                wrongPassword.fill(0)
            }
        } finally {
            validPassword.fill(0)
            validSalt.fill(0)
            clearSyntheticInputs()
        }
    }

    private fun assertInvalid(
        candidatePassword: ByteArray,
        candidateSalt: ByteArray,
        memoryKib: Int,
        operations: Long,
        samples: Int,
    ) {
        val result = JSONObject(
            NativeArgon2Calibration.runSynthetic(
                password = candidatePassword,
                salt = candidateSalt,
                memoryKib = memoryKib,
                operations = operations,
                samples = samples,
            ),
        )
        assertFalse(result.getBoolean("ok"))
        assertEquals("invalidRequest", result.getString("error"))
    }

    private fun runNative(memoryKib: Int, operations: Long, samples: Int): JSONObject =
        JSONObject(
            NativeArgon2Calibration.runSynthetic(
                password = password,
                salt = salt,
                memoryKib = memoryKib,
                operations = operations,
                samples = samples,
            ),
        )

    private fun clearSyntheticInputs() {
        password.fill(0)
        salt.fill(0)
    }

    private fun String.hexBytes(): ByteArray {
        require(length % 2 == 0)
        return chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }

    private fun isPhysicalDevice(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        val model = Build.MODEL.lowercase()
        return Build.SUPPORTED_ABIS.firstOrNull() == "arm64-v8a" &&
            listOf("generic", "emulator", "sdk_gphone", "vbox").none(fingerprint::contains) &&
            listOf("goldfish", "ranchu", "vbox").none(hardware::contains) &&
            !model.contains("emulator")
    }

    private fun batteryPercent(context: Context): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val capacity = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        check(capacity in 0..100) { "Battery capacity is unavailable; evidence cannot be emitted" }
        return capacity
    }

    private fun thermalStatus(powerManager: PowerManager): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            when (powerManager.currentThermalStatus) {
                PowerManager.THERMAL_STATUS_NONE -> "none"
                PowerManager.THERMAL_STATUS_LIGHT -> "light"
                PowerManager.THERMAL_STATUS_MODERATE -> "moderate"
                PowerManager.THERMAL_STATUS_SEVERE -> "severe"
                PowerManager.THERMAL_STATUS_CRITICAL -> "critical"
                PowerManager.THERMAL_STATUS_EMERGENCY -> "emergency"
                PowerManager.THERMAL_STATUS_SHUTDOWN -> "shutdown"
                else -> "unknown"
            }
        } else {
            "unavailable-api-${Build.VERSION.SDK_INT}"
        }

    private companion object {
        const val LIBSODIUM_SOURCE_SHA256 =
            "9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf"
    }
}

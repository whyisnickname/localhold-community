// SPDX-License-Identifier: MPL-2.0
package dev.localhold.mobilestress

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.PowerManager
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.SecureRandom
import java.util.concurrent.CancellationException
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MobileStressInstrumentedTest {
    @Test
    fun selectedPhysicalEvidence() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val arguments = InstrumentationRegistry.getArguments()
        val revision = arguments.getString("buildRevision") ?: "0000000"
        val attachmentGib = arguments.getString("attachmentGib")?.toInt() ?: 1
        require(Regex("^[0-9a-fA-F]{7,64}$").matches(revision))
        require(attachmentGib == 1 || attachmentGib == 5)
        check(context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            "release-optimized target required"
        }

        val recordKey = ByteArray(32) { index -> (index + 11).toByte() }
        val attachmentKey = ByteArray(32) { index -> (index + 101).toByte() }
        val secureRandom = SecureRandom()
        val recordNonceState = AtomicNonceStateStore()
        val attachmentNonceState = AtomicNonceStateStore()
        val recordNonceAllocator = diagnosticAllocator(recordNonceState, secureRandom, 0x31)
        val attachmentNonceAllocator = diagnosticAllocator(attachmentNonceState, secureRandom, 0x41)
        val recordFile = context.cacheDir.resolve("localhold-stage2-record-blobs.bin")
        recordFile.delete()
        try {
            val recordEvidence = collectRecordEvidence(
                context,
                revision,
                recordFile,
                recordKey,
                recordNonceState,
                recordNonceAllocator,
            )
            println("LOCALHOLD_RECORD_EVIDENCE " + recordEvidence)
            val attachmentEvidence =
                collectAttachmentEvidence(
                    context,
                    revision,
                    attachmentGib,
                    attachmentKey,
                    attachmentNonceState,
                    attachmentNonceAllocator,
                )
            println("LOCALHOLD_ATTACHMENT_EVIDENCE " + attachmentEvidence)
        } finally {
            recordKey.fill(0)
            attachmentKey.fill(0)
            recordFile.delete()
            context.cacheDir.resolve(recordFile.name + ".tmp").delete()
        }
    }

    private fun collectRecordEvidence(
        context: Context,
        revision: String,
        recordFile: java.io.File,
        key: ByteArray,
        nonceState: AtomicNonceStateStore,
        nonceAllocator: NonceAllocatorProtocol,
    ): JSONObject {
        val pssBefore = Debug.getPss()
        EncryptedRecordBlobStore(recordFile, key, nonceAllocator).use { store ->
            // Publish a complete prior generation first so the measured write
            // exercises replace-existing semantics, including API 24-25 Os.rename.
            val prior = store.writeSynthetic(1)
            assertEquals(1, prior.recordCount)
            assertTrue(recordFile.isFile)

            val writeStarted = SystemClock.elapsedRealtimeNanos()
            val write = store.writeSynthetic(RECORD_COUNT)
            val writeMs = nanosToMillis(SystemClock.elapsedRealtimeNanos() - writeStarted)
            assertEquals(RECORD_COUNT, write.recordCount)
            assertEquals(RECORD_COUNT, write.uniqueNonceCount)
            val nonceCounterAfter = checkNotNull(nonceState.snapshot()).nextCounter
            assertEquals((RECORD_COUNT + 1).toULong(), nonceCounterAfter)
            assertFalse(recordFile.resolveSibling(recordFile.name + ".tmp").exists())
            assertFalse(store.containsPlaintextSentinel())

            val unlockStarted = SystemClock.elapsedRealtimeNanos()
            val unlock = store.unlockAndBuildIndex()
            val unlockMs = nanosToMillis(SystemClock.elapsedRealtimeNanos() - unlockStarted)
            val pssAfterUnlock = Debug.getPss()
            assertEquals(RECORD_COUNT, unlock.indexedRecordCount)
            assertEquals(setOf("record-09999"), store.query(unlock.handle, "needle9999"))

            store.corruptCiphertext(RECORD_COUNT / 2)
            val corruptionRejected = try {
                store.unlockAndBuildIndex()
                false
            } catch (_: GeneralSecurityException) {
                true
            }
            assertTrue(corruptionRejected)
            val lastValidIndexPreserved =
                store.query(unlock.handle, "needle9999") == setOf("record-09999")
            assertTrue(lastValidIndexPreserved)

            store.lock()
            val staleSessionRejected = try {
                store.query(unlock.handle, "needle9999")
                false
            } catch (_: IllegalStateException) {
                true
            }
            assertTrue(staleSessionRejected)
            val pssDeltaMiB = maxOf(0.0, (pssAfterUnlock - pssBefore).toDouble() / 1024.0)
            assertTrue("record PSS delta must remain bounded", pssDeltaMiB < MAX_PSS_DELTA_MIB)

            return baseEvidence(context, revision)
                .put("evidence_type", "record")
                .put("record_count", write.recordCount)
                .put("stored_bytes", write.storedBytes)
                .put("unique_nonce_count", write.uniqueNonceCount)
                .put("ciphertext_sha256", write.ciphertextSHA256)
                .put("write_ms", writeMs)
                .put("unlock_ms", unlockMs)
                .put("token_count", unlock.tokenCount)
                .put("memory_before_mib", pssBefore.toDouble() / 1024.0)
                .put("memory_after_unlock_mib", pssAfterUnlock.toDouble() / 1024.0)
                .put("memory_delta_mib", pssDeltaMiB)
                .put("plaintext_sentinel_on_disk", false)
                .put("corruption_rejected", corruptionRejected)
                .put("last_valid_index_preserved", lastValidIndexPreserved)
                .put("stale_session_rejected", staleSessionRejected)
                .put("atomic_replacement_exercised", true)
                .put("nonce_counter_after", nonceCounterAfter.toLong())
        }
    }

    private fun collectAttachmentEvidence(
        context: Context,
        revision: String,
        attachmentGib: Int,
        key: ByteArray,
        nonceState: AtomicNonceStateStore,
        nonceAllocator: NonceAllocatorProtocol,
    ): JSONObject {
        val totalBytes = attachmentGib.toLong() * 1024L * 1024L * 1024L
        val target = DiagnosticTransactionalTarget()
        var peakPss = Debug.getPss()
        val pssBefore = peakPss
        val started = SystemClock.elapsedRealtimeNanos()
        val result = AttachmentStreamHarness(key, nonceAllocator).use { harness ->
            val streamed = harness.encryptSynthetic(totalBytes, target) { chunk ->
                if (chunk % 64 == 0) peakPss = maxOf(peakPss, Debug.getPss())
            }
            peakPss = maxOf(peakPss, Debug.getPss())
            assertTrue(target.promoted)
            assertEquals(streamed.chunkCount, streamed.uniqueNonceCount)
            assertEquals(totalBytes, streamed.totalPlaintextBytes)

            val emptyTarget = DiagnosticTransactionalTarget()
            val empty = harness.encryptSynthetic(0, emptyTarget)
            assertEquals(0, empty.chunkCount)
            assertTrue(emptyTarget.promoted)

            val shortTarget = DiagnosticTransactionalTarget()
            val short = harness.encryptSynthetic(CHUNK_BYTES + 123L, shortTarget)
            assertEquals(123, short.finalChunkBytes)
            assertTrue(shortTarget.promoted)

            val cancelTarget = DiagnosticTransactionalTarget()
            val cancellationPreservedPrevious = try {
                harness.encryptSynthetic(3L * CHUNK_BYTES, cancelTarget, cancelAfterChunks = 1)
                false
            } catch (_: CancellationException) {
                cancelTarget.currentVersion == "previous-valid" && !cancelTarget.promoted
            }
            assertTrue(cancellationPreservedPrevious)

            val fullTarget = DiagnosticTransactionalTarget(failAfterBytes = CHUNK_BYTES.toLong())
            val storageFullPreservedPrevious = try {
                harness.encryptSynthetic(2L * CHUNK_BYTES, fullTarget)
                false
            } catch (_: IOException) {
                fullTarget.currentVersion == "previous-valid" && !fullTarget.promoted
            }
            assertTrue(storageFullPreservedPrevious)
            assertTrue(harness.corruptedChunkFailsAuthentication())
            assertEquals(
                (streamed.chunkCount + AUXILIARY_ATTACHMENT_NONCES).toULong(),
                checkNotNull(nonceState.snapshot()).nextCounter,
            )

            streamed to JSONObject()
                .put("empty_stream_promoted", emptyTarget.promoted)
                .put("short_final_chunk_bytes", short.finalChunkBytes)
                .put("cancellation_preserved_previous", cancellationPreservedPrevious)
                .put("storage_full_preserved_previous", storageFullPreservedPrevious)
                .put("corruption_rejected", true)
        }
        val elapsedMs = nanosToMillis(SystemClock.elapsedRealtimeNanos() - started)
        val pssDeltaMiB = maxOf(0.0, (peakPss - pssBefore).toDouble() / 1024.0)
        assertTrue("attachment PSS delta must remain bounded", pssDeltaMiB < MAX_PSS_DELTA_MIB)

        return baseEvidence(context, revision)
            .put("evidence_type", "attachment")
            .put("total_plaintext_bytes", result.first.totalPlaintextBytes)
            .put("chunk_bytes", CHUNK_BYTES)
            .put("chunk_count", result.first.chunkCount)
            .put("unique_nonce_count", result.first.uniqueNonceCount)
            .put("emitted_bytes", result.first.emittedBytes)
            .put("final_chunk_bytes", result.first.finalChunkBytes)
            .put("manifest_sha256", result.first.manifestSHA256)
            .put("elapsed_ms", elapsedMs)
            .put("memory_before_mib", pssBefore.toDouble() / 1024.0)
            .put("peak_memory_mib", peakPss.toDouble() / 1024.0)
            .put("memory_delta_mib", pssDeltaMiB)
            .put(
                "nonce_counter_after",
                checkNotNull(nonceState.snapshot()).nextCounter.toLong(),
            )
            .put("fault_paths", result.second)
    }

    private fun baseEvidence(context: Context, revision: String): JSONObject {
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo().also(activityManager::getMemoryInfo)
        val batteryManager =
            context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val battery = batteryManager
            .getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        check(battery in 0..100) { "battery capacity unavailable" }
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return JSONObject()
            .put("schema_version", 1)
            .put("platform", "android")
            .put("physical_device", isPhysicalDevice())
            .put("build_revision", revision)
            .put("build_mode", "release")
            .put("manufacturer", Build.MANUFACTURER.ifBlank { "unknown" })
            .put("model", Build.MODEL.ifBlank { "unknown" })
            .put("os_version", Build.VERSION.RELEASE.ifBlank { Build.VERSION.SDK_INT.toString() })
            .put("abi", Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown")
            .put("ram_mib", memory.totalMem / (1024L * 1024L))
            .put("memory_metric", "pss")
            .put("low_memory_after", memory.lowMemory)
            .put("battery_percent", battery)
            .put("power_saver", powerManager.isPowerSaveMode)
            .put("thermal", thermalStatus(powerManager))
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
            "unavailable-api-" + Build.VERSION.SDK_INT
        }

    private fun nanosToMillis(value: Long): Double = value.toDouble() / 1_000_000.0

    private fun diagnosticAllocator(
        store: AtomicNonceStateStore,
        random: SecureRandom,
        keyGenerationByte: Int,
    ): NonceAllocatorProtocol {
        val allocator =
            NonceAllocatorProtocol(store) { size -> ByteArray(size).also(random::nextBytes) }
        allocator.initializeForNewKey(ByteArray(16) { keyGenerationByte.toByte() }).fill(0)
        return allocator
    }

    private companion object {
        const val RECORD_COUNT = 10_000
        const val CHUNK_BYTES = 1024 * 1024
        const val MAX_PSS_DELTA_MIB = 256.0
        const val AUXILIARY_ATTACHMENT_NONCES = 5
    }
}

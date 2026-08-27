// SPDX-License-Identifier: MPL-2.0
package dev.localhold.mobilestress

import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.GeneralSecurityException
import java.security.SecureRandom
import java.util.concurrent.CancellationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class MobileStressHostTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun tenThousandEncryptedRecordsRemainSearchableOnlyInCurrentSession() {
        val key = syntheticKey()
        val file = temporaryFolder.newFile("records.bin")
        file.delete()
        val nonceState = AtomicNonceStateStore()
        val nonceAllocator = diagnosticAllocator(nonceState, 0x31)
        try {
            EncryptedRecordBlobStore(file, key, nonceAllocator, ::hostAtomicReplace).use { store ->
                val write = store.writeSynthetic(10_000)
                assertEquals(10_000, write.uniqueNonceCount)
                assertFalse(store.containsPlaintextSentinel())
                val replacement = store.writeSynthetic(10_000)
                assertEquals(10_000, replacement.uniqueNonceCount)
                assertEquals(20_000uL, checkNotNull(nonceState.snapshot()).nextCounter)
                assertFalse(File(file.parentFile, file.name + ".tmp").exists())
                val unlocked = store.unlockAndBuildIndex()
                assertEquals(setOf("record-09999"), store.query(unlocked.handle, "needle9999"))

                store.corruptCiphertext(5_000)
                val rejected = try {
                    store.unlockAndBuildIndex()
                    false
                } catch (_: GeneralSecurityException) {
                    true
                }
                assertTrue(rejected)
                assertEquals(setOf("record-09999"), store.query(unlocked.handle, "needle9999"))
                store.lock()
                val staleRejected = try {
                    store.query(unlocked.handle, "needle9999")
                    false
                } catch (_: IllegalStateException) {
                    true
                }
                assertTrue(staleRejected)
            }
        } finally {
            key.fill(0)
        }
    }

    @Test
    fun attachmentChunksAndFaultPathsPreservePreviousVersion() {
        val key = syntheticKey()
        val nonceState = AtomicNonceStateStore()
        val nonceAllocator = diagnosticAllocator(nonceState, 0x41)
        try {
            AttachmentStreamHarness(key, nonceAllocator).use { harness ->
                val target = DiagnosticTransactionalTarget()
                val result = harness.encryptSynthetic(10L * 1024L * 1024L, target)
                assertEquals(10, result.chunkCount)
                assertEquals(result.chunkCount, result.uniqueNonceCount)
                assertTrue(target.promoted)

                val empty = DiagnosticTransactionalTarget()
                assertEquals(0, harness.encryptSynthetic(0, empty).chunkCount)
                assertTrue(empty.promoted)

                val short = DiagnosticTransactionalTarget()
                assertEquals(
                    123,
                    harness.encryptSynthetic(1024L * 1024L + 123L, short).finalChunkBytes,
                )

                val cancelled = DiagnosticTransactionalTarget()
                try {
                    harness.encryptSynthetic(3L * 1024L * 1024L, cancelled, cancelAfterChunks = 1)
                    error("cancellation should fail")
                } catch (_: CancellationException) {
                    assertEquals("previous-valid", cancelled.currentVersion)
                    assertFalse(cancelled.promoted)
                }

                val full = DiagnosticTransactionalTarget(failAfterBytes = 1024L * 1024L)
                try {
                    harness.encryptSynthetic(2L * 1024L * 1024L, full)
                    error("storage full should fail")
                } catch (_: IOException) {
                    assertEquals("previous-valid", full.currentVersion)
                    assertFalse(full.promoted)
                }
                assertTrue(harness.corruptedChunkFailsAuthentication())
                assertEquals(15uL, checkNotNull(nonceState.snapshot()).nextCounter)
            }
        } finally {
            key.fill(0)
        }
    }

    private fun syntheticKey(): ByteArray = ByteArray(32) { (it + 11).toByte() }

    private fun diagnosticAllocator(
        store: AtomicNonceStateStore,
        keyGenerationByte: Int,
    ): NonceAllocatorProtocol {
        val random = SecureRandom()
        val allocator = NonceAllocatorProtocol(store) { size -> ByteArray(size).also(random::nextBytes) }
        allocator.initializeForNewKey(ByteArray(16) { keyGenerationByte.toByte() }).fill(0)
        return allocator
    }

    private fun hostAtomicReplace(source: File, destination: File) {
        Files.move(
            source.toPath(),
            destination.toPath(),
            StandardCopyOption.ATOMIC_MOVE,
            StandardCopyOption.REPLACE_EXISTING,
        )
    }
}

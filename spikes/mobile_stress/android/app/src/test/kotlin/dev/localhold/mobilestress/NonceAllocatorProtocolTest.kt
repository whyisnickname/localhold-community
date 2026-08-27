// SPDX-License-Identifier: MPL-2.0
package dev.localhold.mobilestress

import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class NonceAllocatorProtocolTest {
    @Test
    fun missingStateFailsClosedUntilExplicitNewKeyInitialization() {
        val store = AtomicNonceStateStore()
        val allocator = NonceAllocatorProtocol(store) { size ->
            assertEquals(4, size)
            "01020304".hex()
        }
        assertThrows(IllegalStateException::class.java) { allocator.reserve() }
        allocator.initializeForNewKey(ByteArray(16) { 0x22 }).fill(0)
        assertEquals(0uL, store.snapshot()!!.nextCounter)
        assertEquals("010203040000000000000000", allocator.reserve().nonce.hex())
        assertThrows(IllegalStateException::class.java) {
            allocator.initializeForNewKey(ByteArray(16) { 0x33 })
        }
    }

    @Test
    fun deterministicLayoutIsEpochThenUnsignedBigEndianCounter() {
        val store = AtomicNonceStateStore(state(epoch = "01020304".hex(), counter = 0uL))
        val allocator = NonceAllocatorProtocol(store, ::unexpectedRandom)
        assertEquals("010203040000000000000000", allocator.reserve().nonce.hex())
        assertEquals("010203040000000000000001", allocator.reserve().nonce.hex())
    }

    @Test
    fun concurrentReservationsAreUnique() {
        val store = AtomicNonceStateStore(state(epoch = "11223344".hex(), counter = 0uL))
        val allocator = NonceAllocatorProtocol(store, ::unexpectedRandom)
        val nonces = Collections.synchronizedSet(HashSet<String>())
        val threads = 16
        val perThread = 2_000
        val pool = Executors.newFixedThreadPool(threads)
        repeat(threads) {
            pool.submit {
                repeat(perThread) { assertTrue(nonces.add(allocator.reserve().nonce.hex())) }
            }
        }
        pool.shutdown()
        assertTrue(pool.awaitTermination(30, TimeUnit.SECONDS))
        assertEquals(threads * perThread, nonces.size)
        assertEquals((threads * perThread).toULong(), store.snapshot()!!.nextCounter)
    }

    @Test
    fun faultBeforeCommitDoesNotAdvanceButFaultAfterCommitCannotReuse() {
        val store = AtomicNonceStateStore(state(epoch = "01020304".hex(), counter = 41uL))
        val allocator = NonceAllocatorProtocol(store, ::unexpectedRandom)

        assertThrows(SyntheticNonceCommitFailure::class.java) {
            allocator.reserve(NonceCommitFault.BEFORE_COMMIT)
        }
        assertEquals(41uL, store.snapshot()!!.nextCounter)

        assertThrows(SyntheticNonceCommitFailure::class.java) {
            allocator.reserve(NonceCommitFault.AFTER_COMMIT_BEFORE_RETURN)
        }
        assertEquals(42uL, store.snapshot()!!.nextCounter)
        assertEquals("01020304000000000000002a", allocator.reserve().nonce.hex())
    }

    @Test
    fun exhaustionFailsClosedWithoutUnsignedWrap() {
        val store = AtomicNonceStateStore(
            state(epoch = "01020304".hex(), counter = ULong.MAX_VALUE),
        )
        val allocator = NonceAllocatorProtocol(store, ::unexpectedRandom)
        assertThrows(IllegalStateException::class.java) { allocator.reserve() }
        assertEquals(ULong.MAX_VALUE, store.snapshot()!!.nextCounter)
    }

    @Test
    fun restoredWritableCloneRequiresNewKeyGenerationBeforeFirstReservation() {
        val originalState = state(epoch = "01020304".hex(), counter = 7uL)
        val original = NonceAllocatorProtocol(AtomicNonceStateStore(originalState), ::unexpectedRandom)
        val sequence = listOf("aabbccdd".hex())
        val cursor = AtomicInteger()
        val cloneStore = AtomicNonceStateStore(originalState)
        val clone = NonceAllocatorProtocol(cloneStore) { sequence[cursor.getAndIncrement()].copyOf() }

        val originalNonce = original.reserve().nonce
        assertThrows(IllegalStateException::class.java) {
            clone.rotateAfterKeyChange(ByteArray(16) { 0x11 })
        }
        assertEquals(7uL, cloneStore.snapshot()!!.nextCounter)
        val newGeneration = clone.rotateAfterKeyChange(ByteArray(16) { 0x22 })
        val cloneNonce = clone.reserve().nonce

        assertTrue(newGeneration.contentEquals(ByteArray(16) { 0x22 }))
        assertEquals("010203040000000000000007", originalNonce.hex())
        assertEquals("aabbccdd0000000000000000", cloneNonce.hex())
        assertFalse(originalNonce.copyOfRange(0, 4).contentEquals(cloneNonce.copyOfRange(0, 4)))
    }

    private fun state(epoch: ByteArray, counter: ULong): NonceDomainState =
        NonceDomainState(ByteArray(16) { 0x11 }, epoch, counter)

    private fun unexpectedRandom(size: Int): ByteArray =
        error("unexpected random request for $size bytes")

    private fun String.hex(): ByteArray = chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    private fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }
}

// SPDX-License-Identifier: MPL-2.0
package dev.localhold.mobilestress

enum class NonceCommitFault {
    NONE,
    BEFORE_COMMIT,
    AFTER_COMMIT_BEFORE_RETURN,
}

class SyntheticNonceCommitFailure : IllegalStateException("synthetic nonce transaction failure")

data class NonceDomainState(
    val keyGenerationId: ByteArray,
    val epoch: ByteArray,
    val nextCounter: ULong,
) {
    init {
        require(keyGenerationId.size == KEY_GENERATION_ID_BYTES)
        require(epoch.size == NONCE_EPOCH_BYTES)
    }

    fun copyState(): NonceDomainState =
        NonceDomainState(keyGenerationId.copyOf(), epoch.copyOf(), nextCounter)

    companion object {
        const val KEY_GENERATION_ID_BYTES = 16
        const val NONCE_EPOCH_BYTES = 4
    }
}

data class NonceReservation(
    val keyGenerationId: ByteArray,
    val nonce: ByteArray,
)

/**
 * Diagnostic stand-in for the single durable transaction required in Stage 4.
 * Committed state is copied before publication so callers cannot mutate it.
 */
class AtomicNonceStateStore(initialState: NonceDomainState? = null) {
    private val monitor = Any()
    private var committedState = initialState?.copyState()

    fun <T> transact(
        fault: NonceCommitFault = NonceCommitFault.NONE,
        transition: (NonceDomainState?) -> Pair<NonceDomainState, T>,
    ): T = synchronized(monitor) {
        val (next, result) = transition(committedState?.copyState())
        if (fault == NonceCommitFault.BEFORE_COMMIT) throw SyntheticNonceCommitFailure()
        committedState = next.copyState()
        if (fault == NonceCommitFault.AFTER_COMMIT_BEFORE_RETURN) {
            throw SyntheticNonceCommitFailure()
        }
        result
    }

    fun snapshot(): NonceDomainState? = synchronized(monitor) { committedState?.copyState() }
}

/** Native-owned allocation protocol. Callers can request a reservation, never a nonce value. */
class NonceAllocatorProtocol(
    private val store: AtomicNonceStateStore,
    private val secureBytes: (Int) -> ByteArray,
) {
    fun reserve(fault: NonceCommitFault = NonceCommitFault.NONE): NonceReservation =
        store.transact(fault) { existing ->
            val state = checkNotNull(existing) {
                "nonce state missing; initialize only after creating a new key"
            }
            check(state.nextCounter != ULong.MAX_VALUE) { "nonce counter exhausted" }
            val nonce = nonce(state.epoch, state.nextCounter)
            val next = state.copy(nextCounter = state.nextCounter + 1uL).copyState()
            next to NonceReservation(state.keyGenerationId.copyOf(), nonce)
        }

    fun initializeForNewKey(
        keyGenerationId: ByteArray,
        fault: NonceCommitFault = NonceCommitFault.NONE,
    ): ByteArray {
        require(keyGenerationId.size == NonceDomainState.KEY_GENERATION_ID_BYTES)
        return store.transact(fault) { existing ->
            check(existing == null) { "nonce state already initialized" }
            val epoch = secureBytes(NonceDomainState.NONCE_EPOCH_BYTES)
                .also { require(it.size == NonceDomainState.NONCE_EPOCH_BYTES) }
            val state = NonceDomainState(
                keyGenerationId = keyGenerationId.copyOf(),
                epoch = epoch,
                nextCounter = 0uL,
            )
            state to state.keyGenerationId.copyOf()
        }
    }

    fun rotateAfterKeyChange(
        newKeyGenerationId: ByteArray,
        fault: NonceCommitFault = NonceCommitFault.NONE,
    ): ByteArray {
        require(newKeyGenerationId.size == NonceDomainState.KEY_GENERATION_ID_BYTES)
        return store.transact(fault) { existing ->
            val previous = checkNotNull(existing) {
                "nonce state missing; initialize only after creating a new key"
            }
            check(!newKeyGenerationId.contentEquals(previous.keyGenerationId)) {
                "writer-domain rotation requires a new key generation"
            }
            var epoch = secureBytes(NonceDomainState.NONCE_EPOCH_BYTES)
                .also { require(it.size == NonceDomainState.NONCE_EPOCH_BYTES) }
            while (epoch.contentEquals(previous.epoch)) {
                epoch.fill(0)
                epoch = secureBytes(NonceDomainState.NONCE_EPOCH_BYTES)
                    .also { require(it.size == NonceDomainState.NONCE_EPOCH_BYTES) }
            }
            val replacement = NonceDomainState(
                keyGenerationId = newKeyGenerationId.copyOf(),
                epoch = epoch,
                nextCounter = 0uL,
            )
            replacement to replacement.keyGenerationId.copyOf()
        }
    }

    private fun nonce(epoch: ByteArray, counter: ULong): ByteArray =
        ByteArray(NONCE_BYTES).also { output ->
            epoch.copyInto(output)
            for (offset in 0 until ULong.SIZE_BYTES) {
                output[NonceDomainState.NONCE_EPOCH_BYTES + offset] =
                    (counter shr ((ULong.SIZE_BYTES - 1 - offset) * 8)).toByte()
            }
        }

    private companion object {
        const val NONCE_BYTES = 12
    }
}

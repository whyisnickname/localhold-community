// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Base64
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.security.SecureRandom
import java.util.concurrent.ConcurrentHashMap
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

private const val MASTER_MAGIC = 0x4c484d31
private const val PAYLOAD_MAGIC = 0x4c485031
private const val RECOVERY_MAGIC = 0x4c485231
private const val FORMAT_VERSION: Byte = 1
private const val KDF_MEMORY_KIB = 98_304
private const val KDF_OPERATIONS = 3L
private const val DEK_BYTES = 32
private const val SALT_BYTES = 16
private const val KEY_GENERATION_BYTES = 16
private const val NONCE_BYTES = 12
private const val TAG_BITS = 128
private const val MAX_PAYLOAD_BYTES = 2 * 1024 * 1024
private const val MAX_AAD_BYTES = 4 * 1024
private const val MASTER_ENVELOPE_BYTES = 106
private const val RECOVERY_ENVELOPE_BYTES = 81
private const val MASTER_FRESHNESS_MILLIS = 30L * 24L * 60L * 60L * 1000L
private const val SENSITIVE_SESSION_FRESHNESS_MILLIS = 5L * 60L * 1000L

internal class NativeVaultCryptoService(context: Context) {
    private val random = SecureRandom()
    private val sessions = ConcurrentHashMap<String, Session>()
    private val sessionMonitor = Any()
    private val recoveryCeremonies = ConcurrentHashMap<String, RecoveryCeremony>()
    private val mnemonic = RecoveryMnemonicCodec(context)
    private val allocator = DurableNonceAllocator(
        context.getSharedPreferences("localhold_nonce_state_v1", Context.MODE_PRIVATE),
        random,
    )
    private val masterFreshness = MasterCredentialFreshnessStore(
        context.getSharedPreferences("localhold_master_freshness_v1", Context.MODE_PRIVATE),
    )

    fun create(request: CreateVaultKeyRequest): VaultSessionReply = guarded {
        withWiped(request.masterPassword) {
            requireVaultId(request.vaultId)
            requirePassword(request.masterPassword)
            val dek = randomBytes(DEK_BYTES)
            val keyGeneration = randomBytes(KEY_GENERATION_BYTES)
            val salt = randomBytes(SALT_BYTES)
            val kek = derive(request.masterPassword, salt)
            try {
                allocator.initialize(keyGeneration)
                val envelope = wrapMaster(request.vaultId, dek, keyGeneration, salt, kek)
                val handle = createSession(
                    request.vaultId,
                    keyGeneration,
                    dek,
                    SessionOrigin.MASTER,
                )
                if (!masterFreshness.record(request.vaultId)) {
                    close(handle)
                    throw BridgeFailure(KeyBridgeErrorCode.INTERNAL_FAILURE)
                }
                VaultSessionReply(
                    sessionHandle = handle,
                    keyGenerationId = encode(keyGeneration),
                    vaultKeyEnvelope = envelope,
                )
            } finally {
                kek.fill(0)
                dek.fill(0)
            }
        }
    }

    fun open(request: OpenVaultSessionRequest): VaultSessionReply = guarded {
        withWiped(request.masterPassword) {
            requireVaultId(request.vaultId)
            requirePassword(request.masterPassword)
            val parsed = parseMasterEnvelope(request.vaultKeyEnvelope)
            allocator.requirePresent(parsed.keyGeneration)
            val kek = derive(request.masterPassword, parsed.salt)
            val reply = try {
                val dek = try {
                    decryptAesGcm(
                        key = kek,
                        nonce = parsed.nonce,
                        ciphertext = parsed.wrappedDek,
                        aad = masterAad(request.vaultId, parsed.keyGeneration),
                    )
                } catch (_: AEADBadTagException) {
                    throw BridgeFailure(KeyBridgeErrorCode.INVALID_CREDENTIALS)
                }
                try {
                    VaultSessionReply(
                        sessionHandle = createSession(
                            request.vaultId,
                            parsed.keyGeneration,
                            dek,
                            SessionOrigin.MASTER,
                        ),
                        keyGenerationId = encode(parsed.keyGeneration),
                    )
                } finally {
                    dek.fill(0)
                }
            } finally {
                kek.fill(0)
            }
            if (!masterFreshness.record(request.vaultId)) {
                reply.sessionHandle?.let(::close)
                throw BridgeFailure(KeyBridgeErrorCode.INTERNAL_FAILURE)
            }
            reply
        }
    }

    fun encrypt(request: EncryptPayloadRequest): PayloadReply = guardedPayload {
        withWiped(request.plaintext) {
            if (request.plaintext.size > MAX_PAYLOAD_BYTES ||
                request.authenticatedData.isEmpty() ||
                request.authenticatedData.size > MAX_AAD_BYTES
            ) {
                throw BridgeFailure(KeyBridgeErrorCode.PAYLOAD_TOO_LARGE)
            }
            val session = requireSession(request.sessionHandle)
            try {
                val nonce = allocator.reserve(session.keyGeneration)
                val encrypted = encryptAesGcm(
                    key = session.dek,
                    nonce = nonce,
                    plaintext = request.plaintext,
                    aad = request.authenticatedData,
                )
                val output = ByteBuffer.allocate(
                    Int.SIZE_BYTES + 1 + KEY_GENERATION_BYTES + NONCE_BYTES + encrypted.size,
                ).order(ByteOrder.BIG_ENDIAN)
                    .putInt(PAYLOAD_MAGIC)
                    .put(FORMAT_VERSION)
                    .put(session.keyGeneration)
                    .put(nonce)
                    .put(encrypted)
                    .array()
                PayloadReply(payload = output)
            } finally {
                session.destroy()
            }
        }
    }

    fun decrypt(request: DecryptPayloadRequest): PayloadReply = guardedPayload {
        if (request.encryptedPayload.size > MAX_PAYLOAD_BYTES + 128 ||
            request.authenticatedData.isEmpty() ||
            request.authenticatedData.size > MAX_AAD_BYTES
        ) {
            throw BridgeFailure(KeyBridgeErrorCode.PAYLOAD_TOO_LARGE)
        }
        val session = requireSession(request.sessionHandle)
        try {
            val buffer = ByteBuffer.wrap(request.encryptedPayload).order(ByteOrder.BIG_ENDIAN)
            if (buffer.remaining() < Int.SIZE_BYTES + 1 + KEY_GENERATION_BYTES + NONCE_BYTES + 16 ||
                buffer.int != PAYLOAD_MAGIC || buffer.get() != FORMAT_VERSION
            ) {
                throw BridgeFailure(KeyBridgeErrorCode.UNSUPPORTED_VERSION)
            }
            val keyGeneration = ByteArray(KEY_GENERATION_BYTES).also(buffer::get)
            if (!keyGeneration.contentEquals(session.keyGeneration)) {
                throw BridgeFailure(KeyBridgeErrorCode.INTEGRITY_FAILURE)
            }
            val nonce = ByteArray(NONCE_BYTES).also(buffer::get)
            val ciphertext = ByteArray(buffer.remaining()).also(buffer::get)
            val plaintext = try {
                decryptAesGcm(
                    key = session.dek,
                    nonce = nonce,
                    ciphertext = ciphertext,
                    aad = request.authenticatedData,
                )
            } catch (_: AEADBadTagException) {
                throw BridgeFailure(KeyBridgeErrorCode.INTEGRITY_FAILURE)
            }
            PayloadReply(payload = plaintext)
        } finally {
            session.destroy()
        }
    }

    fun rewrap(request: RewrapVaultKeyRequest): PayloadReply = guardedPayload {
        withWiped(request.newMasterPassword) {
            requirePassword(request.newMasterPassword)
            val session = requireSensitiveSession(request.sessionHandle)
            val salt = randomBytes(SALT_BYTES)
            val kek = derive(request.newMasterPassword, salt)
            try {
                val reply = PayloadReply(
                    payload = wrapMaster(
                        session.vaultId,
                        session.dek,
                        session.keyGeneration,
                        salt,
                        kek,
                    ),
                )
                if (!masterFreshness.record(session.vaultId)) {
                    throw BridgeFailure(KeyBridgeErrorCode.INTERNAL_FAILURE)
                }
                reply
            } finally {
                kek.fill(0)
                session.destroy()
            }
        }
    }

    fun beginRecovery(sessionHandle: String): RecoveryCeremonyReply = try {
        val session = requireSensitiveSession(sessionHandle)
        try {
            val entropy = randomBytes(DEK_BYTES)
            val words = mnemonic.encode(entropy)
            val nonce = randomBytes(NONCE_BYTES)
            val wrapped = encryptAesGcm(
                key = entropy,
                nonce = nonce,
                plaintext = session.dek,
                aad = recoveryAad(session.vaultId, session.keyGeneration),
            )
            val envelope = ByteBuffer.allocate(RECOVERY_ENVELOPE_BYTES)
                .order(ByteOrder.BIG_ENDIAN)
                .putInt(RECOVERY_MAGIC)
                .put(FORMAT_VERSION)
                .put(session.keyGeneration)
                .put(nonce)
                .put(wrapped)
                .array()
            val positions = generateChallengePositions()
            val handle = encode(randomBytes(16))
            recoveryCeremonies[handle] = RecoveryCeremony(
                words = words,
                entropy = entropy,
                envelope = envelope,
                positions = positions,
            )
            RecoveryCeremonyReply(
                ceremonyHandle = handle,
                challengePositions = positions.map { it.toLong() + 1L },
            )
        } finally {
            session.destroy()
        }
    } catch (failure: BridgeFailure) {
        RecoveryCeremonyReply(error = failure.code)
    } catch (_: Throwable) {
        RecoveryCeremonyReply(error = KeyBridgeErrorCode.INTERNAL_FAILURE)
    }

    /** Native presentation only: this value must never be returned by Pigeon. */
    fun recoveryWordsForPresentation(ceremonyHandle: String): List<String>? =
        recoveryCeremonies[ceremonyHandle]?.words?.toList()

    fun confirmRecovery(request: ConfirmRecoveryKeyRequest): PayloadReply = guardedPayload {
        val ceremony = recoveryCeremonies[request.ceremonyHandle]
            ?: throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        val challengeWords = try {
            parseRecoveryWords(request.challengeWordsUtf8, ceremony.positions.size)
        } finally {
            request.challengeWordsUtf8.fill(0)
        }
        val valid = ceremony.positions.indices.all { index ->
            ceremony.words[ceremony.positions[index]].equals(challengeWords[index], ignoreCase = true)
        }
        if (!valid) throw BridgeFailure(KeyBridgeErrorCode.INVALID_CREDENTIALS)
        recoveryCeremonies.remove(request.ceremonyHandle)
        val output = ceremony.envelope.copyOf()
        ceremony.destroy()
        PayloadReply(payload = output)
    }

    fun openRecovery(request: OpenVaultWithRecoveryRequest): VaultSessionReply = guarded {
        requireVaultId(request.vaultId)
        val entropy = try {
            mnemonic.decode(parseRecoveryWords(request.recoveryPhraseUtf8, 24))
        } catch (_: RecoveryMnemonicFailure) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_CREDENTIALS)
        } finally {
            request.recoveryPhraseUtf8.fill(0)
        }
        try {
            val parsed = parseRecoveryEnvelope(request.recoveryKeyEnvelope)
            allocator.requirePresent(parsed.keyGeneration)
            val dek = try {
                decryptAesGcm(
                    key = entropy,
                    nonce = parsed.nonce,
                    ciphertext = parsed.wrappedDek,
                    aad = recoveryAad(request.vaultId, parsed.keyGeneration),
                )
            } catch (_: AEADBadTagException) {
                throw BridgeFailure(KeyBridgeErrorCode.INVALID_CREDENTIALS)
            }
            try {
                VaultSessionReply(
                    sessionHandle = createSession(
                        request.vaultId,
                        parsed.keyGeneration,
                        dek,
                        SessionOrigin.RECOVERY,
                    ),
                    keyGenerationId = encode(parsed.keyGeneration),
                )
            } finally {
                dek.fill(0)
            }
        } finally {
            entropy.fill(0)
        }
    }

    fun cancelRecovery(ceremonyHandle: String): StatusReply {
        recoveryCeremonies.remove(ceremonyHandle)?.destroy()
        return StatusReply()
    }

    fun biometricMaterial(sessionHandle: String): BiometricMaterial? {
        return synchronized(sessionMonitor) {
            sessions[sessionHandle]
                ?.takeIf(::isSensitiveSessionFresh)
                ?.let { session ->
                BiometricMaterial(
                    vaultId = session.vaultId,
                    keyGeneration = session.keyGeneration.copyOf(),
                    dek = session.dek.copyOf(),
                )
            }
        }
    }

    fun sensitiveSessionError(sessionHandle: String): KeyBridgeErrorCode? =
        synchronized(sessionMonitor) {
            val session = sessions[sessionHandle]
                ?: return@synchronized KeyBridgeErrorCode.SESSION_NOT_FOUND
            if (isSensitiveSessionFresh(session)) null
            else KeyBridgeErrorCode.REAUTHENTICATION_REQUIRED
        }

    fun isMasterCredentialFresh(vaultId: String): Boolean =
        masterFreshness.isFresh(vaultId)

    fun openBiometric(
        vaultId: String,
        keyGeneration: ByteArray,
        dek: ByteArray,
    ): VaultSessionReply = guarded {
        requireVaultId(vaultId)
        if (keyGeneration.size != KEY_GENERATION_BYTES || dek.size != DEK_BYTES) {
            throw BridgeFailure(KeyBridgeErrorCode.INTEGRITY_FAILURE)
        }
        allocator.requirePresent(keyGeneration)
        VaultSessionReply(
            sessionHandle = createSession(
                vaultId,
                keyGeneration,
                dek,
                SessionOrigin.BIOMETRIC,
            ),
            keyGenerationId = encode(keyGeneration),
        )
    }

    fun close(handle: String): StatusReply {
        synchronized(sessionMonitor) { sessions.remove(handle) }?.destroy()
        return StatusReply()
    }

    fun closeAll(): StatusReply {
        recoveryCeremonies.values.forEach(RecoveryCeremony::destroy)
        recoveryCeremonies.clear()
        synchronized(sessionMonitor) {
            sessions.values.forEach(Session::destroy)
            sessions.clear()
        }
        return StatusReply()
    }

    private fun createSession(
        vaultId: String,
        keyGeneration: ByteArray,
        dek: ByteArray,
        origin: SessionOrigin,
    ): String {
        val handle = encode(randomBytes(16))
        synchronized(sessionMonitor) {
            sessions[handle] = Session(
                vaultId,
                keyGeneration.copyOf(),
                dek.copyOf(),
                origin,
                SystemClock.elapsedRealtime(),
            )
        }
        return handle
    }

    private fun requireSession(handle: String): Session = synchronized(sessionMonitor) {
        sessions[handle]?.let {
            Session(
                it.vaultId,
                it.keyGeneration.copyOf(),
                it.dek.copyOf(),
                it.origin,
                it.credentialVerifiedAtMillis,
            )
        }
    } ?: throw BridgeFailure(KeyBridgeErrorCode.SESSION_NOT_FOUND)

    private fun requireSensitiveSession(handle: String): Session {
        val session = requireSession(handle)
        if (!isSensitiveSessionFresh(session)) {
            session.destroy()
            throw BridgeFailure(KeyBridgeErrorCode.REAUTHENTICATION_REQUIRED)
        }
        return session
    }

    private fun isSensitiveSessionFresh(session: Session): Boolean {
        if (session.origin == SessionOrigin.BIOMETRIC) return false
        val elapsed = SystemClock.elapsedRealtime() - session.credentialVerifiedAtMillis
        return elapsed >= 0L && elapsed <= SENSITIVE_SESSION_FRESHNESS_MILLIS
    }

    private fun derive(password: ByteArray, salt: ByteArray): ByteArray =
        NativeArgon2.derive(password, salt, KDF_MEMORY_KIB, KDF_OPERATIONS)
            ?: throw BridgeFailure(KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)

    private fun wrapMaster(
        vaultId: String,
        dek: ByteArray,
        keyGeneration: ByteArray,
        salt: ByteArray,
        kek: ByteArray,
    ): ByteArray {
        val nonce = randomBytes(NONCE_BYTES)
        val wrapped = encryptAesGcm(
            key = kek,
            nonce = nonce,
            plaintext = dek,
            aad = masterAad(vaultId, keyGeneration),
        )
        return ByteBuffer.allocate(MASTER_ENVELOPE_BYTES).order(ByteOrder.BIG_ENDIAN)
            .putInt(MASTER_MAGIC)
            .put(FORMAT_VERSION)
            .putInt(KDF_MEMORY_KIB)
            .putInt(KDF_OPERATIONS.toInt())
            .put(1.toByte())
            .put(salt)
            .put(keyGeneration)
            .put(nonce)
            .put(wrapped)
            .array()
    }

    private fun parseMasterEnvelope(envelope: ByteArray): ParsedMasterEnvelope {
        if (envelope.size != MASTER_ENVELOPE_BYTES) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        }
        val buffer = ByteBuffer.wrap(envelope).order(ByteOrder.BIG_ENDIAN)
        if (buffer.int != MASTER_MAGIC || buffer.get() != FORMAT_VERSION) {
            throw BridgeFailure(KeyBridgeErrorCode.UNSUPPORTED_VERSION)
        }
        if (buffer.int != KDF_MEMORY_KIB ||
            buffer.int != KDF_OPERATIONS.toInt() ||
            buffer.get().toInt() != 1
        ) {
            throw BridgeFailure(KeyBridgeErrorCode.UNSUPPORTED_VERSION)
        }
        return ParsedMasterEnvelope(
            salt = ByteArray(SALT_BYTES).also(buffer::get),
            keyGeneration = ByteArray(KEY_GENERATION_BYTES).also(buffer::get),
            nonce = ByteArray(NONCE_BYTES).also(buffer::get),
            wrappedDek = ByteArray(48).also(buffer::get),
        )
    }

    private fun parseRecoveryEnvelope(envelope: ByteArray): ParsedRecoveryEnvelope {
        if (envelope.size != RECOVERY_ENVELOPE_BYTES) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        }
        val buffer = ByteBuffer.wrap(envelope).order(ByteOrder.BIG_ENDIAN)
        if (buffer.int != RECOVERY_MAGIC || buffer.get() != FORMAT_VERSION) {
            throw BridgeFailure(KeyBridgeErrorCode.UNSUPPORTED_VERSION)
        }
        return ParsedRecoveryEnvelope(
            keyGeneration = ByteArray(KEY_GENERATION_BYTES).also(buffer::get),
            nonce = ByteArray(NONCE_BYTES).also(buffer::get),
            wrappedDek = ByteArray(48).also(buffer::get),
        )
    }

    private fun masterAad(vaultId: String, keyGeneration: ByteArray): ByteArray =
        "localhold.master-wrapper.v1|$vaultId|${encode(keyGeneration)}".encodeToByteArray()

    private fun recoveryAad(vaultId: String, keyGeneration: ByteArray): ByteArray =
        "localhold.recovery-wrapper.v1|$vaultId|${encode(keyGeneration)}".encodeToByteArray()

    private fun generateChallengePositions(): List<Int> {
        val positions = linkedSetOf<Int>()
        while (positions.size < 4) positions += random.nextInt(24)
        return positions.sorted()
    }

    private fun requirePassword(password: ByteArray) {
        if (password.isEmpty() || password.size > 1024) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        }
        val decoded = try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(password))
        } catch (_: CharacterCodingException) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        }
        try {
            var index = 0
            var codePoints = 0
            while (index < decoded.limit()) {
                val current = decoded[index]
                when {
                    Character.isHighSurrogate(current) -> {
                        if (index + 1 >= decoded.limit() ||
                            !Character.isLowSurrogate(decoded[index + 1])
                        ) {
                            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
                        }
                        index += 2
                    }
                    Character.isLowSurrogate(current) -> {
                        throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
                    }
                    else -> index += 1
                }
                codePoints += 1
            }
            if (codePoints < 15) {
                throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
            }
        } finally {
            for (index in 0 until decoded.limit()) decoded.put(index, '\u0000')
        }
    }

    private inline fun <T> withWiped(buffer: ByteArray, operation: () -> T): T =
        try {
            operation()
        } finally {
            buffer.fill(0)
        }

    private fun requireVaultId(vaultId: String) {
        if (!Regex("^[A-Za-z0-9_-]{22}$").matches(vaultId)) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        }
    }

    private fun parseRecoveryWords(bytes: ByteArray, expectedWords: Int): List<String> {
        if (bytes.isEmpty() || bytes.size > 512 || bytes.any { byte ->
                val value = byte.toInt() and 0xff
                value != 0x20 && value !in 0x41..0x5a && value !in 0x61..0x7a
            }
        ) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        }
        val words = bytes.toString(Charsets.US_ASCII).split(' ')
        if (words.size != expectedWords || words.any { it.isEmpty() || it.length > 16 }) {
            throw BridgeFailure(KeyBridgeErrorCode.INVALID_REQUEST)
        }
        return words
    }

    private fun randomBytes(size: Int) = ByteArray(size).also(random::nextBytes)

    private fun encode(value: ByteArray): String =
        Base64.encodeToString(value, Base64.NO_WRAP or Base64.NO_PADDING or Base64.URL_SAFE)

    private inline fun guarded(block: () -> VaultSessionReply): VaultSessionReply = try {
        block()
    } catch (failure: BridgeFailure) {
        VaultSessionReply(error = failure.code)
    } catch (_: Throwable) {
        VaultSessionReply(error = KeyBridgeErrorCode.INTERNAL_FAILURE)
    }

    private inline fun guardedPayload(block: () -> PayloadReply): PayloadReply = try {
        block()
    } catch (failure: BridgeFailure) {
        PayloadReply(error = failure.code)
    } catch (_: Throwable) {
        PayloadReply(error = KeyBridgeErrorCode.INTERNAL_FAILURE)
    }
}

internal class DurableNonceAllocator(
    private val preferences: SharedPreferences,
    private val random: SecureRandom,
) {
    private val monitor = Any()

    fun initialize(keyGeneration: ByteArray) = synchronized(monitor) {
        val prefix = prefix(keyGeneration)
        if (preferences.contains("$prefix.epoch") || preferences.contains("$prefix.counter")) {
            throw BridgeFailure(KeyBridgeErrorCode.INTEGRITY_FAILURE)
        }
        val committed = preferences.edit()
            .putInt("$prefix.epoch", random.nextInt())
            .putLong("$prefix.counter", 0L)
            .commit()
        if (!committed) throw BridgeFailure(KeyBridgeErrorCode.INTERNAL_FAILURE)
    }

    fun requirePresent(keyGeneration: ByteArray) = synchronized(monitor) {
        val prefix = prefix(keyGeneration)
        if (!preferences.contains("$prefix.epoch") || !preferences.contains("$prefix.counter")) {
            throw BridgeFailure(KeyBridgeErrorCode.INTEGRITY_FAILURE)
        }
    }

    fun reserve(keyGeneration: ByteArray): ByteArray = synchronized(monitor) {
        val prefix = prefix(keyGeneration)
        if (!preferences.contains("$prefix.epoch") || !preferences.contains("$prefix.counter")) {
            throw BridgeFailure(KeyBridgeErrorCode.INTEGRITY_FAILURE)
        }
        val counter = preferences.getLong("$prefix.counter", -1L)
        if (counter < 0 || counter == Long.MAX_VALUE) {
            throw BridgeFailure(KeyBridgeErrorCode.INTEGRITY_FAILURE)
        }
        val epoch = preferences.getInt("$prefix.epoch", 0)
        if (!preferences.edit().putLong("$prefix.counter", counter + 1L).commit()) {
            throw BridgeFailure(KeyBridgeErrorCode.INTERNAL_FAILURE)
        }
        ByteBuffer.allocate(NONCE_BYTES).order(ByteOrder.BIG_ENDIAN)
            .putInt(epoch)
            .putLong(counter)
            .array()
    }

    private fun prefix(keyGeneration: ByteArray): String =
        Base64.encodeToString(
            keyGeneration,
            Base64.NO_WRAP or Base64.NO_PADDING or Base64.URL_SAFE,
        )
}

private class MasterCredentialFreshnessStore(
    private val preferences: SharedPreferences,
) {
    fun record(vaultId: String): Boolean =
        preferences.edit().putLong(vaultId, System.currentTimeMillis()).commit()

    fun isFresh(vaultId: String): Boolean {
        val verifiedAt = preferences.getLong(vaultId, -1L)
        val now = System.currentTimeMillis()
        return verifiedAt > 0L && now >= verifiedAt && now - verifiedAt <= MASTER_FRESHNESS_MILLIS
    }
}

private enum class SessionOrigin { MASTER, RECOVERY, BIOMETRIC }

private data class Session(
    val vaultId: String,
    val keyGeneration: ByteArray,
    val dek: ByteArray,
    val origin: SessionOrigin,
    val credentialVerifiedAtMillis: Long,
) {
    fun destroy() {
        keyGeneration.fill(0)
        dek.fill(0)
    }
}

private data class ParsedMasterEnvelope(
    val salt: ByteArray,
    val keyGeneration: ByteArray,
    val nonce: ByteArray,
    val wrappedDek: ByteArray,
)

private data class ParsedRecoveryEnvelope(
    val keyGeneration: ByteArray,
    val nonce: ByteArray,
    val wrappedDek: ByteArray,
)

private data class RecoveryCeremony(
    val words: List<String>,
    val entropy: ByteArray,
    val envelope: ByteArray,
    val positions: List<Int>,
) {
    fun destroy() {
        entropy.fill(0)
        envelope.fill(0)
    }
}

internal data class BiometricMaterial(
    val vaultId: String,
    val keyGeneration: ByteArray,
    val dek: ByteArray,
) {
    fun destroy() {
        keyGeneration.fill(0)
        dek.fill(0)
    }
}

private class BridgeFailure(val code: KeyBridgeErrorCode) : RuntimeException()

private fun encryptAesGcm(
    key: ByteArray,
    nonce: ByteArray,
    plaintext: ByteArray,
    aad: ByteArray,
): ByteArray = Cipher.getInstance("AES/GCM/NoPadding").run {
    init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, nonce))
    updateAAD(aad)
    doFinal(plaintext)
}

private fun decryptAesGcm(
    key: ByteArray,
    nonce: ByteArray,
    ciphertext: ByteArray,
    aad: ByteArray,
): ByteArray = Cipher.getInstance("AES/GCM/NoPadding").run {
    init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, nonce))
    updateAAD(aad)
    doFinal(ciphertext)
}

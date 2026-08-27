// SPDX-License-Identifier: MPL-2.0
package dev.localhold.mobilestress

import java.io.Closeable
import java.io.IOException
import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.concurrent.CancellationException
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

data class AttachmentStreamResult(
    val totalPlaintextBytes: Long,
    val chunkCount: Int,
    val uniqueNonceCount: Int,
    val emittedBytes: Long,
    val finalChunkBytes: Int,
    val manifestSHA256: String,
)

class DiagnosticTransactionalTarget(
    private val failAfterBytes: Long? = null,
) {
    var currentVersion: String = "previous-valid"
        private set
    var partialBytes: Long = 0
        private set
    var lastAbortedBytes: Long = 0
        private set
    var promoted: Boolean = false
        private set

    fun begin(): OutputStream {
        partialBytes = 0
        promoted = false
        return object : OutputStream() {
            override fun write(value: Int) {
                reserve(1)
            }

            override fun write(buffer: ByteArray, offset: Int, length: Int) {
                require(offset >= 0 && length >= 0 && offset + length <= buffer.size)
                reserve(length)
            }

            private fun reserve(length: Int) {
                val next = partialBytes + length
                if (failAfterBytes != null && next > failAfterBytes) {
                    throw IOException("synthetic storage full")
                }
                partialBytes = next
            }
        }
    }

    fun promote(manifestSHA256: String) {
        currentVersion = manifestSHA256
        promoted = true
    }

    fun abort() {
        lastAbortedBytes = partialBytes
        partialBytes = 0
        promoted = false
    }
}

class AttachmentStreamHarness(
    keyBytes: ByteArray,
    private val nonceAllocator: NonceAllocatorProtocol,
) : Closeable {
    private val key = keyBytes.copyOf()

    init {
        require(key.size == KEY_BYTES)
    }

    fun encryptSynthetic(
        totalPlaintextBytes: Long,
        target: DiagnosticTransactionalTarget,
        cancelAfterChunks: Int? = null,
        onChunk: ((Int) -> Unit)? = null,
    ): AttachmentStreamResult {
        require(totalPlaintextBytes in 0..MAX_DIAGNOSTIC_BYTES)
        require(cancelAfterChunks == null || cancelAfterChunks >= 0)
        val output = target.begin()
        val plaintext = ByteArray(CHUNK_BYTES)
        val ciphertext = ByteArray(CHUNK_BYTES + TAG_BYTES)
        val manifestDigest = MessageDigest.getInstance("SHA-256")
        val nonces = HashSet<String>()
        var processed = 0L
        var chunkIndex = 0
        var finalChunkBytes = 0
        try {
            while (processed < totalPlaintextBytes) {
                if (cancelAfterChunks != null && chunkIndex >= cancelAfterChunks) {
                    throw CancellationException("synthetic cancellation")
                }
                val plaintextLength = minOf(CHUNK_BYTES.toLong(), totalPlaintextBytes - processed).toInt()
                plaintext.fill((chunkIndex and 0xff).toByte(), 0, plaintextLength)
                val reservation = nonceAllocator.reserve()
                val nonce = reservation.nonce
                var ciphertextLength = 0
                try {
                    check(nonces.add(nonce.toHex())) { "attachment nonce reuse" }
                    val aad = aad(chunkIndex, totalPlaintextBytes, plaintextLength)
                    val cipher = Cipher.getInstance(CIPHER)
                    cipher.init(
                        Cipher.ENCRYPT_MODE,
                        SecretKeySpec(key, "AES"),
                        GCMParameterSpec(TAG_BITS, nonce),
                    )
                    cipher.updateAAD(aad)
                    ciphertextLength = cipher.doFinal(
                        plaintext,
                        0,
                        plaintextLength,
                        ciphertext,
                        0,
                    )
                    check(ciphertextLength == plaintextLength + TAG_BYTES)

                    output.write(nonce)
                    output.write(intBytes(ciphertextLength))
                    output.write(ciphertext, 0, ciphertextLength)
                    manifestDigest.update(nonce)
                    manifestDigest.update(aad)
                    manifestDigest.update(ciphertext, ciphertextLength - TAG_BYTES, TAG_BYTES)
                    manifestDigest.update(intBytes(plaintextLength))
                } finally {
                    ciphertext.fill(0, 0, ciphertextLength)
                    reservation.keyGenerationId.fill(0)
                    nonce.fill(0)
                }

                processed += plaintextLength
                finalChunkBytes = plaintextLength
                chunkIndex += 1
                onChunk?.invoke(chunkIndex)
            }
            val manifestHash = manifestDigest.digest().toHex()
            target.promote(manifestHash)
            return AttachmentStreamResult(
                totalPlaintextBytes = processed,
                chunkCount = chunkIndex,
                uniqueNonceCount = nonces.size,
                emittedBytes = target.partialBytes,
                finalChunkBytes = finalChunkBytes,
                manifestSHA256 = manifestHash,
            )
        } catch (error: Throwable) {
            target.abort()
            throw error
        } finally {
            plaintext.fill(0)
            ciphertext.fill(0)
            nonces.clear()
        }
    }

    fun corruptedChunkFailsAuthentication(): Boolean {
        val reservation = nonceAllocator.reserve()
        val nonce = reservation.nonce
        val aad = aad(chunkIndex = 0, totalBytes = 37, plaintextLength = 37)
        val plaintext = ByteArray(37) { (it + 1).toByte() }
        val encryptor = Cipher.getInstance(CIPHER)
        encryptor.init(
            Cipher.ENCRYPT_MODE,
            SecretKeySpec(key, "AES"),
            GCMParameterSpec(TAG_BITS, nonce),
        )
        encryptor.updateAAD(aad)
        val ciphertext = encryptor.doFinal(plaintext)
        ciphertext[ciphertext.lastIndex] = (ciphertext.last().toInt() xor 0x01).toByte()
        return try {
            val decryptor = Cipher.getInstance(CIPHER)
            decryptor.init(
                Cipher.DECRYPT_MODE,
                SecretKeySpec(key, "AES"),
                GCMParameterSpec(TAG_BITS, nonce),
            )
            decryptor.updateAAD(aad)
            val unexpectedPlaintext = decryptor.doFinal(ciphertext)
            unexpectedPlaintext.fill(0)
            false
        } catch (_: AEADBadTagException) {
            true
        } finally {
            reservation.keyGenerationId.fill(0)
            nonce.fill(0)
            plaintext.fill(0)
            ciphertext.fill(0)
        }
    }

    override fun close() {
        key.fill(0)
    }

    private fun aad(chunkIndex: Int, totalBytes: Long, plaintextLength: Int): ByteArray =
        ByteBuffer.allocate(AAD_BYTES)
            .order(ByteOrder.BIG_ENDIAN)
            .putInt(FORMAT_VERSION)
            .put(ATTACHMENT_ID)
            .putLong(chunkIndex.toLong())
            .putLong(totalBytes)
            .putInt(plaintextLength)
            .array()

    private fun intBytes(value: Int): ByteArray =
        ByteBuffer.allocate(Int.SIZE_BYTES).order(ByteOrder.BIG_ENDIAN).putInt(value).array()

    private fun ByteArray.toHex(): String = joinToString(separator = "") { "%02x".format(it) }

    private companion object {
        const val KEY_BYTES = 32
        const val CHUNK_BYTES = 1024 * 1024
        const val NONCE_BYTES = 12
        const val TAG_BYTES = 16
        const val TAG_BITS = 128
        const val FORMAT_VERSION = 1
        const val AAD_BYTES = 4 + 16 + 8 + 8 + 4
        const val MAX_DIAGNOSTIC_BYTES = 5L * 1024L * 1024L * 1024L
        const val CIPHER = "AES/GCM/NoPadding"
        val ATTACHMENT_ID = byteArrayOf(
            0x4c, 0x6f, 0x63, 0x61, 0x6c, 0x68, 0x6f, 0x6c,
            0x64, 0x2d, 0x73, 0x74, 0x61, 0x67, 0x65, 0x32,
        )
    }
}

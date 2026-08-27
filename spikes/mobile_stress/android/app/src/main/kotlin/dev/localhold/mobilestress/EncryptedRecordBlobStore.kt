// SPDX-License-Identifier: MPL-2.0
package dev.localhold.mobilestress

import android.os.Build
import android.system.Os
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.Closeable
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

data class RecordWriteResult(
    val recordCount: Int,
    val storedBytes: Long,
    val uniqueNonceCount: Int,
    val ciphertextSHA256: String,
)

data class RecordUnlockResult(
    val handle: RecordSearchSession,
    val indexedRecordCount: Int,
    val tokenCount: Int,
)

class RecordSearchSession internal constructor(internal val generation: Long)

class EncryptedRecordBlobStore(
    private val storageFile: File,
    keyBytes: ByteArray,
    private val nonceAllocator: NonceAllocatorProtocol,
    private val atomicPublisher: (File, File) -> Unit = AndroidAtomicFilePublisher::replace,
) : Closeable {
    private val key = keyBytes.copyOf()
    private var generation = 1L
    private var currentIndex: MutableMap<String, MutableSet<String>>? = null

    init {
        require(key.size == KEY_BYTES)
    }

    fun writeSynthetic(recordCount: Int): RecordWriteResult {
        require(recordCount in 1..MAX_RECORDS)
        storageFile.parentFile?.mkdirs()
        val temporaryFile = File(storageFile.parentFile, storageFile.name + ".tmp")
        val nonces = HashSet<String>(recordCount)
        val ciphertextDigest = MessageDigest.getInstance("SHA-256")
        try {
            FileOutputStream(temporaryFile).use { fileOutput ->
                DataOutputStream(BufferedOutputStream(fileOutput)).use { output ->
                    output.writeInt(MAGIC)
                    output.writeInt(FORMAT_VERSION)
                    output.writeInt(recordCount)
                    for (index in 0 until recordCount) {
                        val recordId = "record-" + index.toString().padStart(5, '0')
                        val plaintext = syntheticPlaintext(index)
                        try {
                            val reservation = nonceAllocator.reserve()
                            val nonce = reservation.nonce
                            var ciphertext = ByteArray(0)
                            try {
                                check(nonces.add(nonce.toHex())) { "nonce reuse" }
                                ciphertext = encrypt(plaintext, nonce, aad(recordId))
                                output.writeUTF(recordId)
                                output.writeInt(nonce.size)
                                output.write(nonce)
                                output.writeInt(ciphertext.size)
                                output.write(ciphertext)
                                ciphertextDigest.update(nonce)
                                ciphertextDigest.update(ciphertext)
                            } finally {
                                ciphertext.fill(0)
                                reservation.keyGenerationId.fill(0)
                                nonce.fill(0)
                            }
                        } finally {
                            plaintext.fill(0)
                        }
                    }
                    output.flush()
                    fileOutput.fd.sync()
                }
            }
            atomicPublisher(temporaryFile, storageFile)
            return RecordWriteResult(
                recordCount = recordCount,
                storedBytes = storageFile.length(),
                uniqueNonceCount = nonces.size,
                ciphertextSHA256 = ciphertextDigest.digest().toHex(),
            )
        } catch (error: Throwable) {
            temporaryFile.delete()
            throw error
        } finally {
            nonces.clear()
        }
    }

    fun unlockAndBuildIndex(): RecordUnlockResult {
        val candidate = HashMap<String, MutableSet<String>>()
        var indexedRecords = 0
        try {
            DataInputStream(BufferedInputStream(FileInputStream(storageFile))).use { input ->
                check(input.readInt() == MAGIC) { "invalid record blob magic" }
                check(input.readInt() == FORMAT_VERSION) { "unsupported record blob version" }
                val recordCount = input.readInt()
                check(recordCount in 1..MAX_RECORDS) { "invalid record count" }
                repeat(recordCount) {
                    val recordId = input.readUTF()
                    val nonceLength = input.readInt()
                    check(nonceLength == NONCE_BYTES)
                    val nonce = ByteArray(nonceLength).also(input::readFully)
                    val ciphertextLength = input.readInt()
                    check(ciphertextLength in TAG_BYTES..MAX_CIPHERTEXT_BYTES)
                    val ciphertext = ByteArray(ciphertextLength).also(input::readFully)
                    var plaintext = ByteArray(0)
                    try {
                        plaintext = decrypt(ciphertext, nonce, aad(recordId))
                        tokenize(plaintext).forEach { token ->
                            candidate.getOrPut(token) { LinkedHashSet() }.add(recordId)
                        }
                        indexedRecords += 1
                    } finally {
                        nonce.fill(0)
                        ciphertext.fill(0)
                        plaintext.fill(0)
                    }
                }
                check(input.read() == -1) { "trailing record blob data" }
            }
        } catch (error: Throwable) {
            clearIndex(candidate)
            throw error
        }

        currentIndex?.let(::clearIndex)
        currentIndex = candidate
        return RecordUnlockResult(
            handle = RecordSearchSession(generation),
            indexedRecordCount = indexedRecords,
            tokenCount = candidate.size,
        )
    }

    fun query(session: RecordSearchSession, rawToken: String): Set<String> {
        check(session.generation == generation) { "stale record search session" }
        val index = checkNotNull(currentIndex) { "vault is locked" }
        return index[normalizeToken(rawToken)]?.toSet() ?: emptySet()
    }

    fun lock() {
        currentIndex?.let(::clearIndex)
        currentIndex = null
        generation += 1
    }

    fun containsPlaintextSentinel(): Boolean {
        val marker = PLAINTEXT_SENTINEL.toByteArray(StandardCharsets.UTF_8)
        val overlap = marker.size - 1
        val buffer = ByteArray(SCAN_BUFFER_BYTES + overlap)
        var carried = 0
        FileInputStream(storageFile).use { input ->
            while (true) {
                val read = input.read(buffer, carried, SCAN_BUFFER_BYTES)
                if (read < 0) return false
                val available = carried + read
                if (buffer.indexOf(marker, available) >= 0) return true
                carried = minOf(overlap, available)
                buffer.copyInto(buffer, destinationOffset = 0, startIndex = available - carried, endIndex = available)
            }
        }
    }

    fun corruptCiphertext(recordIndex: Int) {
        RandomAccessFile(storageFile, "rw").use { file ->
            check(file.readInt() == MAGIC)
            check(file.readInt() == FORMAT_VERSION)
            val recordCount = file.readInt()
            require(recordIndex in 0 until recordCount)
            repeat(recordCount) { index ->
                file.readUTF()
                val nonceLength = file.readInt()
                check(nonceLength == NONCE_BYTES)
                file.seek(file.filePointer + nonceLength)
                val ciphertextLength = file.readInt()
                check(ciphertextLength >= TAG_BYTES)
                val ciphertextStart = file.filePointer
                if (index == recordIndex) {
                    val target = ciphertextStart + ciphertextLength / 2
                    file.seek(target)
                    val original = file.read()
                    check(original >= 0)
                    file.seek(target)
                    file.write(original xor 0x01)
                    return
                }
                file.seek(ciphertextStart + ciphertextLength)
            }
        }
        error("record index not found")
    }

    override fun close() {
        lock()
        key.fill(0)
    }

    private fun encrypt(plaintext: ByteArray, nonce: ByteArray, aad: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(CIPHER)
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(aad)
        return cipher.doFinal(plaintext)
    }

    private fun decrypt(ciphertext: ByteArray, nonce: ByteArray, aad: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(CIPHER)
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(aad)
        return cipher.doFinal(ciphertext)
    }

    private fun tokenize(plaintext: ByteArray): Set<String> {
        val decoded = plaintext.toString(StandardCharsets.UTF_8)
        return TOKEN_SPLIT.split(decoded.lowercase(Locale.ROOT))
            .asSequence()
            .filter { it.length >= 2 }
            .toCollection(LinkedHashSet())
    }

    private fun syntheticPlaintext(index: Int): ByteArray =
        (PLAINTEXT_SENTINEL + index + " title-" + index + " username-" + index +
            "@example.invalid tag-" + (index % 17) + " needle" + index)
            .toByteArray(StandardCharsets.UTF_8)

    private fun aad(recordId: String): ByteArray =
        ("localhold-record-v1|" + recordId).toByteArray(StandardCharsets.UTF_8)

    private fun clearIndex(index: MutableMap<String, MutableSet<String>>) {
        index.values.forEach(MutableSet<String>::clear)
        index.clear()
    }

    private fun normalizeToken(value: String): String = value.lowercase(Locale.ROOT).trim()

    private fun ByteArray.toHex(): String = joinToString(separator = "") { "%02x".format(it) }

    private fun ByteArray.indexOf(needle: ByteArray, limit: Int): Int {
        if (needle.isEmpty()) return 0
        for (start in 0..(limit - needle.size)) {
            var matches = true
            for (offset in needle.indices) {
                if (this[start + offset] != needle[offset]) {
                    matches = false
                    break
                }
            }
            if (matches) return start
        }
        return -1
    }

    private companion object {
        const val MAGIC = 0x4c485242
        const val FORMAT_VERSION = 1
        const val KEY_BYTES = 32
        const val NONCE_BYTES = 12
        const val TAG_BYTES = 16
        const val TAG_BITS = 128
        const val MAX_RECORDS = 10_000
        const val MAX_CIPHERTEXT_BYTES = 64 * 1024
        const val SCAN_BUFFER_BYTES = 64 * 1024
        const val CIPHER = "AES/GCM/NoPadding"
        const val PLAINTEXT_SENTINEL = "LOCALHOLD-PLAINTEXT-"
        val TOKEN_SPLIT = Regex("[^\\p{L}\\p{N}]+")
    }
}

internal object AndroidAtomicFilePublisher {
    fun replace(source: File, destination: File) {
        require(source.canonicalFile.parentFile == destination.canonicalFile.parentFile) {
            "atomic replacement requires one directory"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Files.move(
                source.toPath(),
                destination.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } else {
            // android.system.Os.rename maps to same-filesystem POSIX rename(2),
            // which atomically replaces the destination on API 24–25.
            Os.rename(source.absolutePath, destination.absolutePath)
        }
    }
}

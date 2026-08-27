// SPDX-License-Identifier: MPL-2.0

package dev.localhold.localhold_key_bridge

import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFails

class NativeLocalholdReferenceTest {
    private val key = ByteArray(32) { 0x31 }
    private val chunks = listOf(
        byteArrayOf(),
        "Localhold synthetic".encodeToByteArray(),
        ByteArray(4097) { (it and 0xff).toByte() },
    )

    @Test
    fun KotlinReferenceMatchesCanonicalNodeContainer() {
        val encoded = encode(chunks)
        assertEquals(4581, encoded.size)
        assertEquals(
            "ff1a6b6bbf7227034ba597b3090ff34a85c7c0ca73d7327db854df5ae5a458f5",
            sha256(encoded).hex(),
        )
        val decoded = decode(encoded)
        chunks.zip(decoded).forEach { (expected, actual) ->
            assertContentEquals(expected, actual)
        }

        assertFails { decode(encoded.copyOf(encoded.size - 1)) }
        val tampered = encoded.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
        assertFails { decode(tampered) }
        val duplicateId = encoded.copyOf().also {
            val source = "chunk-00000001".encodeToByteArray()
            val replacement = "chunk-00000000".encodeToByteArray()
            val position = it.indexOfSubArray(source)
            require(position >= 0)
            replacement.copyInto(it, position)
        }
        assertFails { decode(duplicateId) }
    }

    private fun encode(plaintextChunks: List<ByteArray>): ByteArray {
        val combined = plaintextChunks.fold(ByteArray(0)) { result, bytes -> result + bytes }
        val metadata = plaintextChunks.mapIndexed { index, plaintext ->
            ChunkMetadata(
                ciphertextSize = plaintext.size + 28,
                id = chunkId(index),
                plaintextSize = plaintext.size,
            )
        }
        val manifest = canonicalManifest(metadata, sha256(combined).hex()).encodeToByteArray()
        val output = ByteArrayOutputStream()
        output.write("LOCALH1\n".encodeToByteArray())
        output.write(u32(manifest.size))
        output.write(manifest)
        plaintextChunks.forEachIndexed { index, plaintext ->
            val nonce = ByteBuffer.allocate(12).order(ByteOrder.BIG_ENDIAN)
                .putInt(0x4c484231).putLong(index.toLong()).array()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
                init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
                updateAAD(
                    "localhold-backup-v1:${metadata[index].id}:$index:${plaintextChunks.size}:${plaintext.size}"
                        .encodeToByteArray(),
                )
            }
            val ciphertextAndTag = cipher.doFinal(plaintext)
            val ciphertext = ciphertextAndTag.copyOfRange(0, ciphertextAndTag.size - 16)
            val tag = ciphertextAndTag.copyOfRange(ciphertextAndTag.size - 16, ciphertextAndTag.size)
            val chunk = nonce + tag + ciphertext
            output.write(u32(chunk.size))
            output.write(chunk)
        }
        return output.toByteArray()
    }

    private fun decode(container: ByteArray): List<ByteArray> {
        val input = ByteBuffer.wrap(container).order(ByteOrder.BIG_ENDIAN)
        fun take(size: Int): ByteArray {
            require(size >= 0 && input.remaining() >= size)
            return ByteArray(size).also(input::get)
        }
        require(take(8).contentEquals("LOCALH1\n".encodeToByteArray()))
        val manifestLength = input.int
        require(manifestLength in 0..1_048_576)
        val manifest = take(manifestLength).decodeToString()
        val count = Regex("\\\"chunk_count\\\":(\\d+)").find(manifest)!!.groupValues[1].toInt()
        val expectedHash = Regex("\\\"plaintext_sha256\\\":\\\"([0-9a-f]{64})\\\"")
            .find(manifest)!!.groupValues[1]
        require(count in 0..100_000)
        val metadata = Regex(
            "\\{\\\"ciphertext_size\\\":(\\d+),\\\"id\\\":\\\"([^\\\"]+)\\\"," +
                "\\\"plaintext_size\\\":(\\d+)\\}",
        ).findAll(manifest).map { match ->
            ChunkMetadata(
                ciphertextSize = match.groupValues[1].toInt(),
                id = match.groupValues[2],
                plaintextSize = match.groupValues[3].toInt(),
            )
        }.toList()
        require(metadata.size == count)
        require(manifest == canonicalManifest(metadata, expectedHash))
        metadata.forEachIndexed { index, item ->
            require(item.id == chunkId(index))
            require(item.plaintextSize in 0..8 * 1024 * 1024)
            require(item.ciphertextSize == item.plaintextSize + 28)
        }
        val plaintext = List(count) { index ->
            val length = input.int
            require(length == metadata[index].ciphertextSize)
            val chunk = take(length)
            val nonce = chunk.copyOfRange(0, 12)
            val tag = chunk.copyOfRange(12, 28)
            val ciphertext = chunk.copyOfRange(28, chunk.size)
            val expectedNonce = ByteBuffer.allocate(12).order(ByteOrder.BIG_ENDIAN)
                .putInt(0x4c484231).putLong(index.toLong()).array()
            require(nonce.contentEquals(expectedNonce))
            Cipher.getInstance("AES/GCM/NoPadding").run {
                init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
                updateAAD(
                    "localhold-backup-v1:${metadata[index].id}:$index:$count:${metadata[index].plaintextSize}"
                        .encodeToByteArray(),
                )
                doFinal(ciphertext + tag).also { require(it.size == metadata[index].plaintextSize) }
            }
        }
        require(!input.hasRemaining())
        val combined = plaintext.fold(ByteArray(0)) { result, bytes -> result + bytes }
        require(sha256(combined).hex() == expectedHash)
        return plaintext
    }

    private fun u32(value: Int): ByteArray =
        ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(value).array()

    private fun sha256(value: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(value)

    private fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }

    private fun chunkId(index: Int): String = "chunk-%08d".format(index)

    private fun canonicalManifest(metadata: List<ChunkMetadata>, plaintextHash: String): String =
        "{\"algorithm\":\"AES-256-GCM\",\"chunk_count\":${metadata.size},\"chunks\":[" +
            metadata.joinToString(",") {
                "{\"ciphertext_size\":${it.ciphertextSize},\"id\":\"${it.id}\"," +
                    "\"plaintext_size\":${it.plaintextSize}}"
            } + "],\"format_version\":1,\"plaintext_sha256\":\"$plaintextHash\"}"

    private fun ByteArray.indexOfSubArray(needle: ByteArray): Int =
        indices.firstOrNull { start ->
            start + needle.size <= size && needle.indices.all { this[start + it] == needle[it] }
        } ?: -1

    private data class ChunkMetadata(
        val ciphertextSize: Int,
        val id: String,
        val plaintextSize: Int,
    )
}

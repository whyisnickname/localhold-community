// SPDX-License-Identifier: MPL-2.0

package dev.localhold.localhold_key_bridge

import org.junit.jupiter.api.Test
import java.security.GeneralSecurityException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.test.assertContentEquals
import kotlin.test.assertFailsWith

class NativeAesGcmVectorsTest {
    private data class Vector(
        val key: String,
        val nonce: String,
        val aad: String,
        val plaintext: String,
        val ciphertext: String,
        val tag: String,
    )

    private val vectors = listOf(
        Vector("00".repeat(32), "000102030405060708090a0b", "6c6f63616c686f6c642d616164", "", "", "3466421ccd5e61c0a3cda8065e1fe284"),
        Vector("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", "101112131415161718191a1b", "7b2276223a312c2274797065223a227265636f7264227d", "4c6f63616c686f6c642073796e746865746963207265636f7264", "3191fb7725a155dfae557b64610d0136a3392d2e69a734de959d", "894a9c6eec69e231c57fac8bde92b415"),
        Vector("f0".repeat(32), "202122232425262728292a2b", "7661756c743a64656d6f7c7265636f72643a756e69636f6465", "d09fd0b0d180d0bed0bbd18c20f09f94902065cc81", "cc888b71b65a58d1ab092d91705220c1938c024985", "70352c437319e1a2c375276ddbdd9561"),
        Vector("a5".repeat(32), "303132333435363738393a3b", "000102ff", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f", "d67fa54dbc7812cd8e15053ce305a386a21e159dfbc15eb120dd1c6fac3dc542011cd2ee29d94bf1afc0a0ea063844a0f771c8d2a4f44642c2dae2f378c13318", "4417641c643e8ac97b886c27bcbcbaca"),
    )

    @Test
    fun checkedInVectorsMatchByteForByte() {
        vectors.forEach { vector ->
            val encrypted = cipher(Cipher.ENCRYPT_MODE, vector).doFinal(vector.plaintext.hex())
            assertContentEquals((vector.ciphertext + vector.tag).hex(), encrypted)
            val decrypted = cipher(Cipher.DECRYPT_MODE, vector).doFinal(encrypted)
            assertContentEquals(vector.plaintext.hex(), decrypted)
        }
    }

    @Test
    fun nonceAadCiphertextAndTagTamperingFailAuthentication() {
        val vector = vectors[1]
        val sealed = (vector.ciphertext + vector.tag).hex()
        val tamperedNonce = vector.copy(nonce = vector.nonce.flipFirstBit())
        assertFailsWith<GeneralSecurityException> {
            cipher(Cipher.DECRYPT_MODE, tamperedNonce).doFinal(sealed)
        }
        val tamperedAad = vector.copy(aad = vector.aad.flipFirstBit())
        assertFailsWith<GeneralSecurityException> {
            cipher(Cipher.DECRYPT_MODE, tamperedAad).doFinal(sealed)
        }
        repeat(2) { location ->
            val tampered = sealed.copyOf()
            val index = if (location == 0) 0 else tampered.lastIndex
            tampered[index] = (tampered[index].toInt() xor 1).toByte()
            assertFailsWith<GeneralSecurityException> {
                cipher(Cipher.DECRYPT_MODE, vector).doFinal(tampered)
            }
        }
    }

    private fun cipher(mode: Int, vector: Vector): Cipher =
        Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(
                mode,
                SecretKeySpec(vector.key.hex(), "AES"),
                GCMParameterSpec(128, vector.nonce.hex()),
            )
            updateAAD(vector.aad.hex())
        }

    private fun String.hex(): ByteArray {
        require(length % 2 == 0)
        return chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }

    private fun String.flipFirstBit(): String {
        val bytes = hex()
        bytes[0] = (bytes[0].toInt() xor 1).toByte()
        return bytes.joinToString("") { "%02x".format(it) }
    }
}

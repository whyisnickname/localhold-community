// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import android.content.Context
import java.security.MessageDigest
import java.util.Locale

/** BIP-39 entropy/checksum/index encoding only; wallet seed derivation is absent. */
internal class RecoveryMnemonicCodec internal constructor(candidateWords: List<String>) {
    internal constructor(context: Context) : this(
        context.assets.open(ASSET_NAME).bufferedReader(Charsets.UTF_8)
            .useLines { lines -> lines.filter(String::isNotBlank).toList() },
    )

    private val words: List<String> = candidateWords.toList().also(::validateWordList)
    private val indices = words.withIndex().associate { it.value to it.index }

    fun encode(entropy: ByteArray): List<String> {
        require(entropy.size == ENTROPY_BYTES)
        val checksum = MessageDigest.getInstance("SHA-256").digest(entropy)[0].toInt() and 0xff
        return List(WORD_COUNT) { wordPosition ->
            var index = 0
            repeat(BITS_PER_WORD) { bitWithinWord ->
                val bitPosition = wordPosition * BITS_PER_WORD + bitWithinWord
                val bit = if (bitPosition < ENTROPY_BITS) {
                    val source = entropy[bitPosition / 8].toInt() and 0xff
                    (source shr (7 - bitPosition % 8)) and 1
                } else {
                    (checksum shr (7 - (bitPosition - ENTROPY_BITS))) and 1
                }
                index = (index shl 1) or bit
            }
            words[index]
        }
    }

    fun decode(input: List<String>): ByteArray {
        if (input.size != WORD_COUNT) throw RecoveryMnemonicFailure()
        val normalized = input.map { it.lowercase(Locale.US) }
        val entropy = ByteArray(ENTROPY_BYTES)
        var encodedChecksum = 0
        normalized.forEachIndexed { wordPosition, word ->
            val index = indices[word] ?: throw RecoveryMnemonicFailure()
            repeat(BITS_PER_WORD) { bitWithinWord ->
                val bitPosition = wordPosition * BITS_PER_WORD + bitWithinWord
                val bit = (index shr (BITS_PER_WORD - 1 - bitWithinWord)) and 1
                if (bitPosition < ENTROPY_BITS) {
                    val target = bitPosition / 8
                    entropy[target] = (
                        (entropy[target].toInt() and 0xff) or
                            (bit shl (7 - bitPosition % 8))
                        ).toByte()
                } else {
                    encodedChecksum = (encodedChecksum shl 1) or bit
                }
            }
        }
        val expected = MessageDigest.getInstance("SHA-256").digest(entropy)[0].toInt() and 0xff
        if (encodedChecksum != expected) {
            entropy.fill(0)
            throw RecoveryMnemonicFailure()
        }
        return entropy
    }

    private fun validateWordList(candidate: List<String>) {
        require(candidate.size == 2048)
        require(candidate.toSet().size == candidate.size)
        require(candidate == candidate.sorted())
        require(candidate.all { it.matches(Regex("^[a-z]+$")) })
    }

    private companion object {
        const val ASSET_NAME = "bip39_english.txt"
        const val ENTROPY_BYTES = 32
        const val ENTROPY_BITS = ENTROPY_BYTES * 8
        const val WORD_COUNT = 24
        const val BITS_PER_WORD = 11
    }
}

internal class RecoveryMnemonicFailure : RuntimeException()

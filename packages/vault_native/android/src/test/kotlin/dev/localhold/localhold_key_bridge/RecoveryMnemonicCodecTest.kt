// SPDX-License-Identifier: MPL-2.0

package dev.localhold.localhold_key_bridge

import org.junit.jupiter.api.Test
import java.io.File
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

internal class RecoveryMnemonicCodecTest {
    private val words = File("src/main/assets/bip39_english.txt")
        .readLines(Charsets.UTF_8)
        .filter(String::isNotBlank)
    private val codec = RecoveryMnemonicCodec(words)

    @Test
    fun officialAllZeroAndAllOneVectorsRoundTrip() {
        val zero = ByteArray(32)
        val one = ByteArray(32) { 0xff.toByte() }
        val zeroPhrase = codec.encode(zero)
        val onePhrase = codec.encode(one)

        assertEquals(List(23) { "abandon" } + "art", zeroPhrase)
        assertEquals(List(23) { "zoo" } + "vote", onePhrase)
        assertContentEquals(zero, codec.decode(zeroPhrase))
        assertContentEquals(one, codec.decode(onePhrase))
    }

    @Test
    fun checksumUnknownWordAndWrongLengthFailClosed() {
        val phrase = codec.encode(ByteArray(32)).toMutableList()
        phrase[23] = "zoo"
        assertFailsWith<RecoveryMnemonicFailure> { codec.decode(phrase) }
        phrase[23] = "notaword"
        assertFailsWith<RecoveryMnemonicFailure> { codec.decode(phrase) }
        assertFailsWith<RecoveryMnemonicFailure> { codec.decode(phrase.dropLast(1)) }
    }
}

// SPDX-License-Identifier: MPL-2.0
package dev.localhold.autofill.spike

import org.junit.jupiter.api.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class StrictOriginMatcherTest {
    private val signer = "ab".repeat(32)
    private val rotatedSigner = "cd".repeat(32)
    private val actual = OriginEvidence(
        packageName = "com.example.bank",
        certificateSha256 = setOf(signer, rotatedSigner),
        webOrigins = setOf(WebOriginEvidence("login.example.com"), WebOriginEvidence("admin.example.com", 8443)),
    )

    @Test
    fun exactPackageAndSignerMatch() {
        assertTrue(StrictOriginMatcher.matches(SavedAppOrigin("com.example.bank", signer.uppercase()), actual))
        assertTrue(StrictOriginMatcher.matches(SavedAppOrigin("com.example.bank", rotatedSigner), actual))
    }

    @Test
    fun wrongMalformedOrSubstringAppEvidenceFailsClosed() {
        assertFalse(StrictOriginMatcher.matches(SavedAppOrigin("com.example.bank", "ef".repeat(32)), actual))
        assertFalse(StrictOriginMatcher.matches(SavedAppOrigin("com.example.bank", "abc123"), actual))
        assertFalse(StrictOriginMatcher.matches(SavedAppOrigin("example.bank", signer), actual))
        assertFalse(StrictOriginMatcher.matches(SavedAppOrigin("com.example.bank.fake", signer), actual))
    }

    @Test
    fun exactAsciiWebHostAndPortMatch() {
        assertTrue(StrictOriginMatcher.matches(SavedWebOrigin("LOGIN.EXAMPLE.COM"), actual))
        assertFalse(StrictOriginMatcher.matches(SavedWebOrigin("evil.example.com"), actual))
        assertFalse(StrictOriginMatcher.matches(SavedWebOrigin("login.example.com.evil.test"), actual))
        assertFalse(StrictOriginMatcher.matches(SavedWebOrigin("login.example.com", 8443), actual))
        assertTrue(StrictOriginMatcher.matches(SavedWebOrigin("admin.example.com", 8443), actual))
    }

    @Test
    fun malformedAndUnicodeHostsFailClosed() {
        for (host in listOf(".example.com", "example.com.", "example..com", "-bad.example", "bad-.example", "exаmple.com")) {
            assertFalse(StrictOriginMatcher.matches(SavedWebOrigin(host), actual), host)
        }
    }
}

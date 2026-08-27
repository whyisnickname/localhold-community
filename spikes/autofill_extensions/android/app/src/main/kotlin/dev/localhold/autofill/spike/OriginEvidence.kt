// SPDX-License-Identifier: MPL-2.0
package dev.localhold.autofill.spike

data class OriginEvidence(
    val packageName: String,
    val certificateSha256: Set<String>,
    val webOrigins: Set<WebOriginEvidence>,
)

data class WebOriginEvidence(
    val host: String,
    val port: Int = 443,
)

data class SavedAppOrigin(
    val packageName: String,
    val certificateSha256: String,
)

data class SavedWebOrigin(
    val host: String,
    val port: Int = 443,
)

object StrictOriginMatcher {
    fun matches(saved: SavedAppOrigin, actual: OriginEvidence): Boolean {
        val signer = saved.certificateSha256.lowercase()
        return saved.packageName.isNotBlank() &&
            SIGNER.matches(signer) &&
            saved.packageName == actual.packageName &&
            actual.certificateSha256.any { it.lowercase() == signer }
    }

    fun matches(saved: SavedWebOrigin, actual: OriginEvidence): Boolean {
        val savedHost = canonicalWebHostOrNull(saved.host) ?: return false
        if (saved.port !in 1..65_535) return false
        return actual.webOrigins.any { requested ->
            requested.port == saved.port && canonicalWebHostOrNull(requested.host) == savedHost
        }
    }

    fun canonicalWebHostOrNull(raw: String): String? {
        val host = raw.lowercase()
        if (host != raw.lowercase().trim() || host.length !in 1..253 || !ASCII_HOST.matches(host)) {
            return null
        }
        val labels = host.split('.')
        if (labels.any { label ->
                label.isEmpty() || label.length > 63 || label.startsWith('-') || label.endsWith('-')
            }
        ) {
            return null
        }
        return host
    }

    private val SIGNER = Regex("^[0-9a-f]{64}$")
    private val ASCII_HOST = Regex("^[a-z0-9.-]+$")
}

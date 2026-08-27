// SPDX-License-Identifier: MPL-2.0
package dev.localhold.autofill.spike

import android.app.assist.AssistStructure
import android.content.pm.PackageManager
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import java.security.MessageDigest

/**
 * Boundary prototype only: it extracts authenticated origin evidence and
 * deliberately returns no credentials. Production wiring may query the vault
 * only after strict matching and an explicit unlock decision.
 */
class LocalholdAutofillService : AutofillService() {
    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        if (cancellationSignal.isCanceled) {
            callback.onSuccess(null)
            return
        }
        val structure = request.fillContexts.lastOrNull()?.structure
        val packageName = structure?.activityComponent?.packageName
        if (structure == null || packageName.isNullOrBlank()) {
            callback.onSuccess(null)
            return
        }
        // Extraction is intentionally completed before any future vault query.
        extractEvidence(structure, packageName)
        callback.onSuccess(null)
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // The spike never persists form contents.
        callback.onSuccess()
    }

    private fun extractEvidence(
        structure: AssistStructure,
        packageName: String,
    ): OriginEvidence = OriginEvidence(
        packageName = packageName,
        certificateSha256 = signerHashes(packageName),
        webOrigins = collectWebDomains(structure).mapTo(mutableSetOf()) { WebOriginEvidence(it) },
    )

    private fun signerHashes(packageName: String): Set<String> {
        val signers = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES,
                )
                val signingInfo = info.signingInfo ?: return emptySet()
                if (signingInfo.hasMultipleSigners()) {
                    signingInfo.apkContentsSigners
                } else {
                    signingInfo.signingCertificateHistory
                }
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                    .signatures ?: emptyArray()
            }
        } catch (_: PackageManager.NameNotFoundException) {
            return emptySet()
        }
        return signers.mapTo(mutableSetOf()) { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }
    }

    private fun collectWebDomains(structure: AssistStructure): Set<String> {
        val domains = mutableSetOf<String>()
        repeat(structure.windowNodeCount) { windowIndex ->
            collectWebDomains(structure.getWindowNodeAt(windowIndex).rootViewNode, domains)
        }
        return domains
    }

    private fun collectWebDomains(
        node: AssistStructure.ViewNode,
        output: MutableSet<String>,
    ) {
        node.webDomain
            ?.let(StrictOriginMatcher::canonicalWebHostOrNull)
            ?.let(output::add)
        repeat(node.childCount) { index ->
            collectWebDomains(node.getChildAt(index), output)
        }
    }
}

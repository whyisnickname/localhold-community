// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Bundle

class BackupLocationActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // STAGE2_SPIKE_DO_NOT_SHIP: the exported launcher accepts only synthetic
        // entitlement timing and is disabled in every non-debuggable build.
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            finish()
            return
        }
        if (runDiagnosticCommand()) {
            finish()
            return
        }
        val premiumUntil = premiumUntilEpochMillis()
        if (!BackupEntitlementGate.isActive(premiumUntil, System.currentTimeMillis())) {
            finish()
            return
        }
        if (BackupLocationStore(this).currentGrant() == null) {
            startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                    )
                },
                PICK_DIRECTORY,
            )
        } else {
            BackupWorkScheduler.schedule(this, premiumUntil)
            finish()
        }
    }

    @Deprecated("Prototype uses the platform callback to support API 24.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_DIRECTORY && resultCode == RESULT_OK) {
            data?.let(::acceptDirectory)
        }
        finish()
    }

    private fun acceptDirectory(result: Intent) {
        val uri: Uri = result.data ?: return
        val takeFlags = PersistedGrantPolicy.takeFlagsOrNull(result.flags) ?: return
        try {
            contentResolver.takePersistableUriPermission(uri, takeFlags)
        } catch (_: SecurityException) {
            return
        }
        if (BackupLocationStore(this).save(uri)) {
            BackupWorkScheduler.schedule(this, premiumUntilEpochMillis())
        }
    }

    private fun runDiagnosticCommand(): Boolean = when (
        BackupDiagnosticCommand.parse(intent.action)
    ) {
        BackupDiagnosticCommand.CANCEL_SCHEDULE -> {
            BackupWorkScheduler.cancel(this)
            true
        }
        BackupDiagnosticCommand.RELEASE_LOCATION -> {
            val uri = BackupLocationStore(this).currentGrant()
            if (uri != null) {
                try {
                    contentResolver.releasePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                } catch (_: SecurityException) {
                    // A concurrently revoked permission is already the required
                    // fail-closed state; the next run will request a new folder.
                }
            }
            BackupWorkScheduler.cancel(this)
            true
        }
        null -> false
    }

    private fun premiumUntilEpochMillis(): Long =
        intent.getLongExtra(EXTRA_PREMIUM_UNTIL_EPOCH_MILLIS, 0)

    companion object {
        private const val PICK_DIRECTORY = 7001
        const val EXTRA_PREMIUM_UNTIL_EPOCH_MILLIS =
            "dev.localhold.backup.PREMIUM_UNTIL_EPOCH_MILLIS"
    }
}

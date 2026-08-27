// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Boundary prototype: proves background restoration of the persisted SAF grant.
 * Production replaces success with streaming `.localhold` creation and verification.
 */
class BackupPermissionWorker(
    context: Context,
    parameters: WorkerParameters,
) : Worker(context, parameters) {
    override fun doWork(): Result {
        val premiumUntil = inputData.getLong(
            BackupEntitlementGate.INPUT_PREMIUM_UNTIL_EPOCH_MILLIS,
            0,
        )
        return if (
            BackupEntitlementGate.isActive(premiumUntil, System.currentTimeMillis()) &&
            BackupLocationStore(applicationContext).currentGrant() != null
        ) {
            Result.success()
        } else {
            Result.failure()
        }
    }
}

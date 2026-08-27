// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

object BackupWorkScheduler {
    private const val UNIQUE_NAME = "localhold-user-selected-backup"

    fun schedule(context: Context, premiumUntilEpochMillis: Long) {
        require(
            BackupEntitlementGate.isActive(premiumUntilEpochMillis, System.currentTimeMillis()),
        ) { "active Premium entitlement required" }
        val request = PeriodicWorkRequestBuilder<BackupPermissionWorker>(24, TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiresStorageNotLow(true).build())
            .setInputData(
                workDataOf(
                    BackupEntitlementGate.INPUT_PREMIUM_UNTIL_EPOCH_MILLIS to
                        premiumUntilEpochMillis,
                ),
            )
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            UNIQUE_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_NAME)
    }
}

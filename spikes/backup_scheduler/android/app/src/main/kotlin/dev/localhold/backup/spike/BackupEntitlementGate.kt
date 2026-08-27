// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

object BackupEntitlementGate {
    const val INPUT_PREMIUM_UNTIL_EPOCH_MILLIS = "premium_until_epoch_millis"

    fun isActive(premiumUntilEpochMillis: Long, nowEpochMillis: Long): Boolean =
        premiumUntilEpochMillis > 0 && premiumUntilEpochMillis > nowEpochMillis
}

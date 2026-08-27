// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupEntitlementGateTest {
    @Test
    fun onlyStrictlyFuturePositiveExpiryAllowsBackup() {
        val now = 1_700_000_000_000L
        assertTrue(BackupEntitlementGate.isActive(now + 1, now))
        assertFalse(BackupEntitlementGate.isActive(now, now))
        assertFalse(BackupEntitlementGate.isActive(now - 1, now))
        assertFalse(BackupEntitlementGate.isActive(0, now))
    }
}

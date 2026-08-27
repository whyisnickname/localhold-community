// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class BiometricWrapperPolicyTest {
    @Test
    fun onlyAvailableStateAllowsDeviceUnwrap() {
        BiometricWrapperState.entries.forEach { state ->
            val expected = if (state == BiometricWrapperState.AVAILABLE) {
                BiometricWrapperAction.UNWRAP_DEVICE_COPY
            } else {
                BiometricWrapperAction.REQUIRE_MASTER_PASSWORD
            }
            assertEquals(expected, BiometricWrapperPolicy.nextAction(state))
        }
    }

    @Test
    fun recreationRequiresSuccessfulMasterUnlockAndExplicitConfirmation() {
        assertTrue(BiometricWrapperPolicy.mayRecreateAfterMasterUnlock(true, true))
        assertFalse(BiometricWrapperPolicy.mayRecreateAfterMasterUnlock(true, false))
        assertFalse(BiometricWrapperPolicy.mayRecreateAfterMasterUnlock(false, true))
        assertFalse(BiometricWrapperPolicy.mayRecreateAfterMasterUnlock(false, false))
    }
}

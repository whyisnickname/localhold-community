// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

internal enum class BiometricWrapperState {
    AVAILABLE,
    CANCELLED,
    LOCKED_OUT,
    UNAVAILABLE,
    INVALIDATED,
}

internal enum class BiometricWrapperAction {
    UNWRAP_DEVICE_COPY,
    REQUIRE_MASTER_PASSWORD,
}

/** Pure fail-safe policy shared by the platform adapter and unit tests. */
internal object BiometricWrapperPolicy {
    fun nextAction(state: BiometricWrapperState): BiometricWrapperAction =
        when (state) {
            BiometricWrapperState.AVAILABLE -> BiometricWrapperAction.UNWRAP_DEVICE_COPY
            BiometricWrapperState.CANCELLED,
            BiometricWrapperState.LOCKED_OUT,
            BiometricWrapperState.UNAVAILABLE,
            BiometricWrapperState.INVALIDATED,
            -> BiometricWrapperAction.REQUIRE_MASTER_PASSWORD
        }

    fun mayRecreateAfterMasterUnlock(masterUnlockSucceeded: Boolean, userConfirmed: Boolean): Boolean =
        masterUnlockSucceeded && userConfirmed
}

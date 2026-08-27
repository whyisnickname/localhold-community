// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

internal object NativeArgon2 {
    init {
        System.loadLibrary("localhold_vault_crypto")
    }

    external fun derive(
        password: ByteArray,
        salt: ByteArray,
        memoryKib: Int,
        operations: Long,
    ): ByteArray?
}

// SPDX-License-Identifier: MPL-2.0
package dev.localhold.argon2.calibration

object NativeArgon2Calibration {
    init { System.loadLibrary("localhold_argon2_calibration") }

    external fun runSynthetic(
        password: ByteArray,
        salt: ByteArray,
        memoryKib: Int,
        operations: Long,
        samples: Int,
    ): String
}

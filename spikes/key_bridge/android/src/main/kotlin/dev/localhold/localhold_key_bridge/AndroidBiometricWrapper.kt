// SPDX-License-Identifier: MPL-2.0

package dev.localhold.localhold_key_bridge

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Stage 2 auth-per-use wrapper boundary. Cipher instances must be passed to a
 * BiometricPrompt CryptoObject; doFinal is called only from its success callback.
 */
internal class AndroidBiometricWrapper(
    private val alias: String,
) {
    data class WrappedValue(
        val nonce: ByteArray,
        val ciphertextAndTag: ByteArray,
    )

    fun enableAfterMasterConfirmation(
        masterUnlockSucceeded: Boolean,
        userConfirmed: Boolean,
    ) {
        require(masterUnlockSucceeded) { "master unlock required" }
        require(userConfirmed) { "explicit biometric enable confirmation required" }
        val keyStore = keyStore()
        keyStore.deleteEntry(alias)
        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG,
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(-1)
        }
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
            .apply { init(builder.build()) }
            .generateKey()
    }

    fun createEncryptCipher(): Cipher = cipher().apply {
        init(Cipher.ENCRYPT_MODE, secretKey())
    }

    fun finishAuthenticatedWrap(
        authenticatedCipher: Cipher,
        value: ByteArray,
        aad: ByteArray,
    ): WrappedValue {
        require(authenticatedCipher.iv.size == 12)
        authenticatedCipher.updateAAD(aad)
        return WrappedValue(
            nonce = authenticatedCipher.iv.copyOf(),
            ciphertextAndTag = authenticatedCipher.doFinal(value),
        )
    }

    fun createDecryptCipher(nonce: ByteArray): Cipher {
        require(nonce.size == 12)
        return cipher().apply {
            init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, nonce))
        }
    }

    fun finishAuthenticatedUnwrap(
        authenticatedCipher: Cipher,
        ciphertextAndTag: ByteArray,
        aad: ByteArray,
    ): ByteArray {
        authenticatedCipher.updateAAD(aad)
        return authenticatedCipher.doFinal(ciphertextAndTag)
    }

    fun deleteAfterMasterConfirmation(masterConfirmed: Boolean) {
        require(masterConfirmed) { "master confirmation required" }
        keyStore().deleteEntry(alias)
    }

    private fun secretKey(): SecretKey =
        (keyStore().getKey(alias, null) as? SecretKey)
            ?: throw IllegalStateException("biometric wrapper unavailable")

    private fun cipher(): Cipher = Cipher.getInstance("AES/GCM/NoPadding")

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply {
        load(null)
    }

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    }
}

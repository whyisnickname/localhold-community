// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.KeyStore
import javax.crypto.Cipher
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal class AndroidBiometricCoordinator(
    private val context: Context,
    private val preferences: SharedPreferences,
    private val activityProvider: () -> FragmentActivity?,
    private val service: () -> NativeVaultCryptoService?,
) {
    private val mutex = Mutex()

    suspend fun enable(sessionHandle: String): StatusReply = mutex.withLock {
        val crypto = service()
            ?: return@withLock StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        crypto.sensitiveSessionError(sessionHandle)?.let { error ->
            return@withLock StatusReply(error = error)
        }
        val material = crypto.biometricMaterial(sessionHandle)
            ?: return@withLock StatusReply(error = KeyBridgeErrorCode.SESSION_NOT_FOUND)
        val alias = alias(material.vaultId)
        val wrapper = AndroidBiometricWrapper(alias)
        try {
            if (!isStrongBiometricAvailable()) {
                return@withLock StatusReply(error = KeyBridgeErrorCode.BIOMETRIC_UNAVAILABLE)
            }
            wrapper.enableAfterMasterConfirmation(
                masterUnlockSucceeded = true,
                userConfirmed = true,
            )
            val authenticated = authenticate(wrapper.createEncryptCipher(), "Enable biometric unlock")
            val wrapped = wrapper.finishAuthenticatedWrap(
                authenticatedCipher = authenticated,
                value = material.dek,
                aad = aad(material.vaultId, material.keyGeneration),
            )
            val envelope = ByteBuffer.allocate(ENVELOPE_BYTES).order(ByteOrder.BIG_ENDIAN)
                .putInt(MAGIC)
                .put(VERSION)
                .put(material.keyGeneration)
                .put(wrapped.nonce)
                .put(wrapped.ciphertextAndTag)
                .array()
            if (!preferences.edit().putString(key(material.vaultId), encode(envelope)).commit()) {
                wrapper.deleteAfterMasterConfirmation(true)
                return@withLock StatusReply(error = KeyBridgeErrorCode.INTERNAL_FAILURE)
            }
            StatusReply()
        } catch (_: KeyPermanentlyInvalidatedException) {
            StatusReply(error = KeyBridgeErrorCode.BIOMETRIC_INVALIDATED)
        } catch (failure: BiometricCoordinatorFailure) {
            StatusReply(error = failure.code)
        } catch (_: Throwable) {
            StatusReply(error = KeyBridgeErrorCode.BIOMETRIC_UNAVAILABLE)
        } finally {
            material.destroy()
        }
    }

    suspend fun open(vaultId: String): VaultSessionReply = mutex.withLock {
        if (!VAULT_ID.matches(vaultId)) {
            return@withLock VaultSessionReply(error = KeyBridgeErrorCode.INVALID_REQUEST)
        }
        val crypto = service()
            ?: return@withLock VaultSessionReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        if (!crypto.isMasterCredentialFresh(vaultId)) {
            return@withLock VaultSessionReply(
                error = KeyBridgeErrorCode.REAUTHENTICATION_REQUIRED,
            )
        }
        val raw = preferences.getString(key(vaultId), null)
            ?: return@withLock VaultSessionReply(error = KeyBridgeErrorCode.BIOMETRIC_UNAVAILABLE)
        val envelope = try {
            decode(raw)
        } catch (_: Throwable) {
            return@withLock VaultSessionReply(error = KeyBridgeErrorCode.INTEGRITY_FAILURE)
        }
        if (envelope.size != ENVELOPE_BYTES) {
            return@withLock VaultSessionReply(error = KeyBridgeErrorCode.INTEGRITY_FAILURE)
        }
        val buffer = ByteBuffer.wrap(envelope).order(ByteOrder.BIG_ENDIAN)
        if (buffer.int != MAGIC || buffer.get() != VERSION) {
            return@withLock VaultSessionReply(error = KeyBridgeErrorCode.UNSUPPORTED_VERSION)
        }
        val keyGeneration = ByteArray(16).also(buffer::get)
        val nonce = ByteArray(12).also(buffer::get)
        val wrappedDek = ByteArray(48).also(buffer::get)
        val wrapper = AndroidBiometricWrapper(alias(vaultId))
        var dek: ByteArray? = null
        try {
            if (!isStrongBiometricAvailable()) {
                return@withLock VaultSessionReply(error = KeyBridgeErrorCode.BIOMETRIC_UNAVAILABLE)
            }
            val cipher = wrapper.createDecryptCipher(nonce)
            val authenticated = authenticate(cipher, "Unlock Localhold")
            dek = wrapper.finishAuthenticatedUnwrap(
                authenticatedCipher = authenticated,
                ciphertextAndTag = wrappedDek,
                aad = aad(vaultId, keyGeneration),
            )
            crypto.openBiometric(vaultId, keyGeneration, dek)
        } catch (_: KeyPermanentlyInvalidatedException) {
            VaultSessionReply(error = KeyBridgeErrorCode.BIOMETRIC_INVALIDATED)
        } catch (failure: BiometricCoordinatorFailure) {
            VaultSessionReply(error = failure.code)
        } catch (_: Throwable) {
            VaultSessionReply(error = KeyBridgeErrorCode.BIOMETRIC_INVALIDATED)
        } finally {
            keyGeneration.fill(0)
            wrappedDek.fill(0)
            dek?.fill(0)
        }
    }

    suspend fun disable(sessionHandle: String): StatusReply = mutex.withLock {
        val crypto = service()
            ?: return@withLock StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        crypto.sensitiveSessionError(sessionHandle)?.let { error ->
            return@withLock StatusReply(error = error)
        }
        val material = crypto.biometricMaterial(sessionHandle)
            ?: return@withLock StatusReply(error = KeyBridgeErrorCode.SESSION_NOT_FOUND)
        try {
            AndroidBiometricWrapper(alias(material.vaultId))
                .deleteAfterMasterConfirmation(true)
            if (!preferences.edit().remove(key(material.vaultId)).commit()) {
                return@withLock StatusReply(error = KeyBridgeErrorCode.INTERNAL_FAILURE)
            }
            StatusReply()
        } catch (_: Throwable) {
            StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        } finally {
            material.destroy()
        }
    }

    fun status(vaultId: String): BiometricStatusReply {
        if (!VAULT_ID.matches(vaultId)) {
            return BiometricStatusReply(
                configured = false,
                invalidated = false,
                error = KeyBridgeErrorCode.INVALID_REQUEST,
            )
        }
        val hasEnvelope = preferences.contains(key(vaultId))
        val hasKey = try {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.containsAlias(alias(vaultId))
        } catch (_: Throwable) {
            return BiometricStatusReply(
                configured = false,
                invalidated = false,
                error = KeyBridgeErrorCode.BIOMETRIC_UNAVAILABLE,
            )
        }
        return BiometricStatusReply(
            configured = hasEnvelope && hasKey,
            invalidated = hasEnvelope && !hasKey,
        )
    }

    private suspend fun authenticate(cipher: Cipher, title: String): Cipher =
        suspendCancellableCoroutine { continuation ->
            val activity = activityProvider()
            if (activity == null) {
                continuation.resumeWithException(
                    BiometricCoordinatorFailure(KeyBridgeErrorCode.PLATFORM_UNAVAILABLE),
                )
                return@suspendCancellableCoroutine
            }
            val executor = ContextCompat.getMainExecutor(context)
            val prompt = BiometricPrompt(
                activity,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        result: BiometricPrompt.AuthenticationResult,
                    ) {
                        val authenticated = result.cryptoObject?.cipher
                        if (authenticated == null) {
                            continuation.resumeWithException(
                                BiometricCoordinatorFailure(
                                    KeyBridgeErrorCode.BIOMETRIC_UNAVAILABLE,
                                ),
                            )
                        } else if (continuation.isActive) {
                            continuation.resume(authenticated)
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        if (!continuation.isActive) return
                        val code = when (errorCode) {
                            BiometricPrompt.ERROR_HW_NOT_PRESENT,
                            BiometricPrompt.ERROR_HW_UNAVAILABLE,
                            BiometricPrompt.ERROR_NO_BIOMETRICS,
                            -> KeyBridgeErrorCode.BIOMETRIC_UNAVAILABLE
                            else -> KeyBridgeErrorCode.INVALID_CREDENTIALS
                        }
                        continuation.resumeWithException(BiometricCoordinatorFailure(code))
                    }
                },
            )
            continuation.invokeOnCancellation { prompt.cancelAuthentication() }
            prompt.authenticate(
                BiometricPrompt.PromptInfo.Builder()
                    .setTitle(title)
                    .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                    .setNegativeButtonText("Use master password")
                    .build(),
                BiometricPrompt.CryptoObject(cipher),
            )
        }

    private fun isStrongBiometricAvailable(): Boolean =
        BiometricManager.from(context).canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG,
        ) == BiometricManager.BIOMETRIC_SUCCESS

    private fun alias(vaultId: String) = "dev.localhold.biometric.$vaultId"
    private fun key(vaultId: String) = "biometric.$vaultId"
    private fun aad(vaultId: String, keyGeneration: ByteArray) =
        "localhold.biometric-wrapper.v1|$vaultId|${encode(keyGeneration)}".encodeToByteArray()
    private fun encode(value: ByteArray): String = Base64.encodeToString(
        value,
        Base64.NO_WRAP or Base64.NO_PADDING or Base64.URL_SAFE,
    )
    private fun decode(value: String): ByteArray =
        Base64.decode(value, Base64.NO_WRAP or Base64.NO_PADDING or Base64.URL_SAFE)

    private companion object {
        const val MAGIC = 0x4c484231
        const val VERSION: Byte = 1
        const val ENVELOPE_BYTES = 81
        val VAULT_ID = Regex("^[A-Za-z0-9_-]{22}$")
    }
}

private class BiometricCoordinatorFailure(
    val code: KeyBridgeErrorCode,
) : RuntimeException()

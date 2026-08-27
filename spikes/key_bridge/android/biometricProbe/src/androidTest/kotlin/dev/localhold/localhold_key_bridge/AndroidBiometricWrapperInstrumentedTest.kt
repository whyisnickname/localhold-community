// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import androidx.test.ext.junit.runners.AndroidJUnit4
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.security.ProviderException
import java.util.UUID
import org.junit.After
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assume.assumeNoException
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidBiometricWrapperInstrumentedTest {
    private val aliases = mutableListOf<String>()

    @After
    fun removeSyntheticAliases() {
        val keyStore = androidKeyStore()
        aliases.forEach(keyStore::deleteEntry)
    }

    @Test
    fun creationRequiresMasterUnlockAndExplicitConfirmation() {
        val alias = newAlias()
        val wrapper = AndroidBiometricWrapper(alias)

        assertThrows(IllegalArgumentException::class.java) {
            wrapper.enableAfterMasterConfirmation(
                masterUnlockSucceeded = false,
                userConfirmed = true,
            )
        }
        assertNull(androidKeyStore().getKey(alias, null))

        assertThrows(IllegalArgumentException::class.java) {
            wrapper.enableAfterMasterConfirmation(
                masterUnlockSucceeded = true,
                userConfirmed = false,
            )
        }
        assertNull(androidKeyStore().getKey(alias, null))
    }

    @Test
    fun eligibleDeviceKeyIsNonExportableAndCannotWrapWithoutAuthentication() {
        val alias = newAlias()
        val wrapper = AndroidBiometricWrapper(alias)
        try {
            wrapper.enableAfterMasterConfirmation(
                masterUnlockSucceeded = true,
                userConfirmed = true,
            )
        } catch (error: ProviderException) {
            assumeNoException("Strong biometric Keystore is unavailable", error)
        } catch (error: GeneralSecurityException) {
            assumeNoException("Strong biometric Keystore is unavailable", error)
        } catch (error: IllegalArgumentException) {
            assumeNoException("Strong biometric Keystore is unavailable", error)
        }

        val key = androidKeyStore().getKey(alias, null)
        assertNull("AndroidKeyStore key material must not be exportable", key.encoded)
        val cipher = try {
            wrapper.createEncryptCipher()
        } catch (error: GeneralSecurityException) {
            assumeNoException("The runtime cannot initialize an auth-per-use key", error)
            return
        }
        assertThrows(GeneralSecurityException::class.java) {
            wrapper.finishAuthenticatedWrap(
                authenticatedCipher = cipher,
                value = ByteArray(32) { 0x42 },
                aad = "localhold-biometric-spike".encodeToByteArray(),
            )
        }

        assertThrows(IllegalArgumentException::class.java) {
            wrapper.deleteAfterMasterConfirmation(masterConfirmed = false)
        }
        wrapper.deleteAfterMasterConfirmation(masterConfirmed = true)
        assertNull(androidKeyStore().getKey(alias, null))
    }

    private fun newAlias(): String =
        "localhold-stage2-${UUID.randomUUID()}".also(aliases::add)

    private fun androidKeyStore(): KeyStore =
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
}

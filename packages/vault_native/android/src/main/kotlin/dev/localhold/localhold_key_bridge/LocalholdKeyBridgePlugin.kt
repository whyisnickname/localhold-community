// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import android.app.Activity
import android.app.Application
import android.app.AlertDialog
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.PersistableBundle
import android.view.WindowManager
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.security.MessageDigest
import java.io.File

class LocalholdKeyBridgePlugin :
    FlutterPlugin,
    ActivityAware,
    Application.ActivityLifecycleCallbacks,
    KeyBridgeHostApi {
    private var service: NativeVaultCryptoService? = null
    private var activity: Activity? = null
    private var applicationContext: Context? = null
    private var biometricCoordinator: AndroidBiometricCoordinator? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var clipboardDigest: ByteArray? = null
    private var clipboardGeneration = 0L
    private var backgroundedAtMillis: Long? = null
    private val backgroundLock = Runnable {
        service?.closeAll()
    }
    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) service?.closeAll()
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        val application = binding.applicationContext as Application
        application.registerActivityLifecycleCallbacks(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            application.registerReceiver(
                screenOffReceiver,
                IntentFilter(Intent.ACTION_SCREEN_OFF),
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            application.registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        }
        service = NativeVaultCryptoService(binding.applicationContext)
        biometricCoordinator = AndroidBiometricCoordinator(
            context = binding.applicationContext,
            preferences = binding.applicationContext.getSharedPreferences(
                "localhold_biometric_state_v1",
                Context.MODE_PRIVATE,
            ),
            activityProvider = { activity as? FragmentActivity },
            service = { service },
        )
        KeyBridgeHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        mainHandler.removeCallbacks(backgroundLock)
        val application = binding.applicationContext as Application
        application.unregisterActivityLifecycleCallbacks(this)
        try {
            application.unregisterReceiver(screenOffReceiver)
        } catch (_: IllegalArgumentException) {
            // Already unregistered during a partial engine teardown.
        }
        service?.closeAll()
        service = null
        biometricCoordinator = null
        applicationContext = null
        KeyBridgeHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onActivityPaused(paused: Activity) {
        if (paused !== activity || paused.isChangingConfigurations) return
        backgroundedAtMillis = SystemClock.elapsedRealtime()
        mainHandler.removeCallbacks(backgroundLock)
        mainHandler.postDelayed(backgroundLock, BACKGROUND_LOCK_MILLIS)
    }

    override fun onActivityResumed(resumed: Activity) {
        if (resumed !== activity) return
        val backgroundedAt = backgroundedAtMillis
        if (backgroundedAt != null &&
            SystemClock.elapsedRealtime() - backgroundedAt >= BACKGROUND_LOCK_MILLIS
        ) {
            service?.closeAll()
        }
        backgroundedAtMillis = null
        mainHandler.removeCallbacks(backgroundLock)
    }

    override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit
    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivityDestroyed(activity: Activity) = Unit

    override fun createVaultKey(request: CreateVaultKeyRequest): VaultSessionReply =
        requireService().create(request)

    override fun openVaultSession(request: OpenVaultSessionRequest): VaultSessionReply =
        requireService().open(request)

    override fun encryptPayload(request: EncryptPayloadRequest): PayloadReply =
        requireService().encrypt(request)

    override fun decryptPayload(request: DecryptPayloadRequest): PayloadReply =
        requireService().decrypt(request)

    override fun rewrapVaultKey(request: RewrapVaultKeyRequest): PayloadReply =
        requireService().rewrap(request)

    override fun beginRecoveryKey(sessionHandle: String): RecoveryCeremonyReply =
        requireService().beginRecovery(sessionHandle)

    override fun presentRecoveryKey(ceremonyHandle: String): StatusReply {
        val currentActivity = activity
            ?: return StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        val words = requireService().recoveryWordsForPresentation(ceremonyHandle)
            ?: return StatusReply(error = KeyBridgeErrorCode.INVALID_REQUEST)
        val text = words.mapIndexed { index, word -> "${index + 1}. $word" }
            .chunked(2)
            .joinToString("\n") { row -> row.joinToString("        ") }
        val dialog = AlertDialog.Builder(currentActivity)
            .setTitle("Localhold recovery key")
            .setMessage(text)
            .setPositiveButton(android.R.string.ok, null)
            .create()
        dialog.setOnDismissListener { dialog.setMessage(null) }
        dialog.setOnShowListener {
            dialog.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        dialog.show()
        return StatusReply()
    }

    override fun confirmRecoveryKey(request: ConfirmRecoveryKeyRequest): PayloadReply =
        requireService().confirmRecovery(request)

    override fun openVaultWithRecovery(request: OpenVaultWithRecoveryRequest): VaultSessionReply =
        requireService().openRecovery(request)

    override fun cancelRecoveryKey(ceremonyHandle: String): StatusReply =
        requireService().cancelRecovery(ceremonyHandle)

    override fun setVaultPrivacyActive(active: Boolean): StatusReply {
        val window = activity?.window
            ?: return StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        if (active) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        return StatusReply()
    }

    override fun copySensitiveClipboard(request: SensitiveClipboardRequest): StatusReply {
        if (request.utf8Value.isEmpty() ||
            request.utf8Value.size > 2 * 1024 * 1024 ||
            request.expirySeconds !in setOf(15L, 30L, 60L, 120L)
        ) {
            request.utf8Value.fill(0)
            return StatusReply(error = KeyBridgeErrorCode.INVALID_REQUEST)
        }
        return try {
            val clipboard = clipboard()
            val value = request.utf8Value.toString(Charsets.UTF_8)
            val clip = ClipData.newPlainText("", value)
            clip.description.extras = (clip.description.extras ?: PersistableBundle()).apply {
                putBoolean("android.content.extra.IS_SENSITIVE", true)
            }
            clipboard.setPrimaryClip(clip)
            clipboardDigest = digest(value)
            clipboardGeneration += 1
            val generation = clipboardGeneration
            mainHandler.postDelayed(
                { if (generation == clipboardGeneration) clearSensitiveClipboard() },
                request.expirySeconds * 1000L,
            )
            StatusReply()
        } catch (_: Throwable) {
            StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        } finally {
            request.utf8Value.fill(0)
        }
    }

    override fun clearSensitiveClipboard(): StatusReply {
        val expected = clipboardDigest ?: return StatusReply()
        return try {
            val clipboard = clipboard()
            val current = clipboard.primaryClip?.getItemAt(0)?.coerceToText(applicationContext)
            if (current != null && MessageDigest.isEqual(expected, digest(current.toString()))) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    clipboard.clearPrimaryClip()
                } else {
                    clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                }
            }
            clipboardDigest?.fill(0)
            clipboardDigest = null
            clipboardGeneration += 1
            StatusReply()
        } catch (_: Throwable) {
            StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        }
    }

    override suspend fun enableBiometric(sessionHandle: String): StatusReply =
        biometricCoordinator?.enable(sessionHandle)
            ?: StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)

    override suspend fun openVaultWithBiometric(vaultId: String): VaultSessionReply =
        biometricCoordinator?.open(vaultId)
            ?: VaultSessionReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)

    override suspend fun disableBiometric(sessionHandle: String): StatusReply =
        biometricCoordinator?.disable(sessionHandle)
            ?: StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)

    override fun biometricStatus(vaultId: String): BiometricStatusReply =
        biometricCoordinator?.status(vaultId)
            ?: BiometricStatusReply(
                configured = false,
                invalidated = false,
                error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE,
            )

    override fun excludePathFromBackup(absolutePath: String): StatusReply {
        val context = applicationContext
            ?: return StatusReply(error = KeyBridgeErrorCode.PLATFORM_UNAVAILABLE)
        return try {
            val candidate = File(absolutePath).canonicalFile
            val dataRoot = context.dataDir.canonicalFile
            if (!candidate.path.startsWith(dataRoot.path + File.separator)) {
                StatusReply(error = KeyBridgeErrorCode.INVALID_REQUEST)
            } else {
                // Android application manifests disable both Auto Backup and
                // device-transfer extraction. This call verifies path scope.
                StatusReply()
            }
        } catch (_: Throwable) {
            StatusReply(error = KeyBridgeErrorCode.INVALID_REQUEST)
        }
    }

    override fun closeSession(sessionHandle: String): StatusReply =
        requireService().close(sessionHandle)

    override fun closeAllSessions(): StatusReply = requireService().closeAll()

    private fun requireService(): NativeVaultCryptoService =
        service ?: throw IllegalStateException("Vault crypto unavailable")

    private fun clipboard(): ClipboardManager =
        applicationContext?.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            ?: throw IllegalStateException("Clipboard unavailable")

    private fun digest(value: String): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(value.encodeToByteArray())

    private companion object {
        const val BACKGROUND_LOCK_MILLIS = 30_000L
    }
}

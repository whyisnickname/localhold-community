// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.TaskStackBuilder
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.RandomAccessFile
import java.net.URI
import java.security.SecureRandom
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Base64
import java.util.Locale
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONObject

internal class AndroidPlatformFeatures(private val context: Context) {
    private val activity = AtomicReference<Activity?>(null)
    private var permissionContinuation:
        kotlinx.coroutines.CancellableContinuation<NotificationPermissionReply>? = null
    private var launcherAction = 0L

    fun attachActivity(value: Activity, intent: Intent?) {
        activity.set(value)
        consumeIntent(intent)
    }

    fun detachActivity(value: Activity?) {
        if (value == null || activity.get() === value) activity.set(null)
    }

    fun consumeIntent(intent: Intent?): Boolean {
        launcherAction = when (intent?.action) {
            ACTION_ADD -> 1L
            ACTION_SEARCH -> 2L
            ACTION_LOCK -> 3L
            else -> return false
        }
        intent.action = Intent.ACTION_MAIN
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return false
        val continuation = permissionContinuation ?: return true
        permissionContinuation = null
        val granted = permissions.indices.any {
            permissions[it] == Manifest.permission.POST_NOTIFICATIONS &&
                results.getOrNull(it) == PackageManager.PERMISSION_GRANTED
        }
        continuation.resume(
            NotificationPermissionReply(
                if (granted) NotificationPermissionCode.AUTHORIZED else NotificationPermissionCode.DENIED,
            ),
        )
        return true
    }

    suspend fun notificationPermissionStatus(): NotificationPermissionReply {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) {
            return NotificationPermissionReply(NotificationPermissionCode.DENIED)
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return NotificationPermissionReply(NotificationPermissionCode.AUTHORIZED)
        }
        val granted = context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) return NotificationPermissionReply(NotificationPermissionCode.AUTHORIZED)
        val requested = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_PERMISSION_REQUESTED, false)
        return NotificationPermissionReply(
            if (requested) NotificationPermissionCode.DENIED
            else NotificationPermissionCode.NOT_DETERMINED,
        )
    }

    suspend fun requestNotificationPermission(): NotificationPermissionReply {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return notificationPermissionStatus()
        }
        val current = activity.get()
            ?: return NotificationPermissionReply(
                NotificationPermissionCode.RESTRICTED,
                PlatformFeatureErrorCode.PLATFORM_UNAVAILABLE,
            )
        if (permissionContinuation != null) {
            return NotificationPermissionReply(
                NotificationPermissionCode.RESTRICTED,
                PlatformFeatureErrorCode.INVALID_REQUEST,
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_PERMISSION_REQUESTED, true).apply()
        return suspendCancellableCoroutine { continuation ->
            permissionContinuation = continuation
            continuation.invokeOnCancellation { permissionContinuation = null }
            current.requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    fun openNotificationSettings(): FeatureStatusReply = try {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        FeatureStatusReply()
    } catch (_: Throwable) {
        FeatureStatusReply(PlatformFeatureErrorCode.PLATFORM_UNAVAILABLE)
    }

    fun resolveWallClock(request: WallClockRequest): WallClockReply =
        AndroidWallClockResolver.resolve(request)

    suspend fun replaceReminder(request: SafeReminderRequest): FeatureStatusReply =
        AndroidReminderStore.replace(context, request)

    fun cancelReminder(syntheticId: String): FeatureStatusReply =
        AndroidReminderStore.cancel(context, syntheticId)

    fun installLauncherShortcuts(): FeatureStatusReply = try {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return FeatureStatusReply()
        val manager = context.getSystemService(ShortcutManager::class.java)
        val iconId = context.applicationInfo.icon
        val definitions = listOf(
            Triple("localhold.add", "Add", ACTION_ADD),
            Triple("localhold.search", "Search", ACTION_SEARCH),
            Triple("localhold.lock", "Lock", ACTION_LOCK),
        )
        manager.dynamicShortcuts = definitions.mapIndexed { index, value ->
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: throw IllegalStateException("Launcher unavailable")
            launch.action = value.third
            ShortcutInfo.Builder(context, value.first)
                .setShortLabel(value.second)
                .setRank(index)
                .setIntent(launch)
                .apply { if (iconId != 0) setIcon(Icon.createWithResource(context, iconId)) }
                .build()
        }
        FeatureStatusReply()
    } catch (_: Throwable) {
        FeatureStatusReply(PlatformFeatureErrorCode.PLATFORM_UNAVAILABLE)
    }

    fun consumeLauncherAction(): LauncherActionReply {
        val value = launcherAction
        launcherAction = 0
        return LauncherActionReply(value)
    }

    fun listInboundShares(): InboundShareListReply =
        AndroidInboundShareStore.list(context)

    fun readInboundShareChunk(request: InboundShareChunkRequest): InboundShareChunkReply =
        AndroidInboundShareStore.read(context, request)

    fun deleteInboundShare(id: String): FeatureStatusReply =
        AndroidInboundShareStore.delete(context, id)

    fun purgeExpiredInboundShares(nowUtcEpochMilliseconds: Long): FeatureStatusReply =
        AndroidInboundShareStore.purge(context, nowUtcEpochMilliseconds)

    companion object {
        const val ACTION_ADD = "dev.localhold.action.ADD"
        const val ACTION_SEARCH = "dev.localhold.action.SEARCH"
        const val ACTION_LOCK = "dev.localhold.action.LOCK"
        private const val PREFS = "localhold_platform_features_v1"
        private const val KEY_PERMISSION_REQUESTED = "notification_permission_requested"
        private const val NOTIFICATION_PERMISSION_REQUEST = 49210
    }
}

internal object AndroidWallClockResolver {
    fun resolve(request: WallClockRequest): WallClockReply = try {
        if (request.timeZoneId.length !in 1..128) return invalid()
        val zone = ZoneId.of(request.timeZoneId)
        val local = LocalDateTime.of(
            request.year.toInt(), request.month.toInt(), request.day.toInt(),
            request.hour.toInt(), request.minute.toInt(),
        )
        val offsets = zone.rules.getValidOffsets(local)
        val pair = when (offsets.size) {
            1 -> ZonedDateTime.ofLocal(local, zone, offsets[0]) to WallClockResolutionCode.UNIQUE
            2 -> ZonedDateTime.ofLocal(local, zone, offsets[0]) to WallClockResolutionCode.EARLIER
            0 -> {
                val transition = zone.rules.getTransition(local) ?: return invalid()
                ZonedDateTime.of(transition.dateTimeAfter, zone) to WallClockResolutionCode.GAP_ADJUSTED
            }
            else -> return invalid()
        }
        WallClockReply(pair.first.toInstant().toEpochMilli(), pair.second)
    } catch (_: Throwable) {
        invalid()
    }

    private fun invalid() = WallClockReply(
        0,
        WallClockResolutionCode.UNIQUE,
        PlatformFeatureErrorCode.INVALID_REQUEST,
    )
}

internal object AndroidReminderStore {
    private const val PREFS = "localhold_safe_reminders_v1"
    private const val CHANNEL = "localhold_reminders"
    private val idPattern = Regex("^[A-Za-z0-9_-]{22}$")

    fun replace(context: Context, request: SafeReminderRequest): FeatureStatusReply = try {
        if (!valid(request)) return FeatureStatusReply(PlatformFeatureErrorCode.INVALID_REQUEST)
        val encoded = JSONObject()
            .put("id", request.syntheticId)
            .put("at", request.utcEpochMilliseconds)
            .put("privacy", request.privacyCode)
            .put("name", request.safeName)
            .put("amount", request.safeAmount)
            .toString()
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(request.syntheticId, encoded).commit()
        schedule(context, request.syntheticId, request.utcEpochMilliseconds)
        FeatureStatusReply()
    } catch (_: Throwable) {
        FeatureStatusReply(PlatformFeatureErrorCode.INTERNAL_FAILURE)
    }

    fun cancel(context: Context, id: String): FeatureStatusReply = try {
        if (!idPattern.matches(id)) return FeatureStatusReply(PlatformFeatureErrorCode.INVALID_REQUEST)
        alarm(context).cancel(pending(context, id))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(id).commit()
        FeatureStatusReply()
    } catch (_: Throwable) {
        FeatureStatusReply(PlatformFeatureErrorCode.INTERNAL_FAILURE)
    }

    fun restore(context: Context) {
        val now = System.currentTimeMillis()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.all.forEach { (id, raw) ->
            val at = runCatching { JSONObject(raw as String).getLong("at") }.getOrNull()
            if (at == null || at <= now || !idPattern.matches(id)) {
                prefs.edit().remove(id).apply()
            } else {
                schedule(context, id, at)
            }
        }
    }

    fun notify(context: Context, id: String) {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(id, null)
            ?: return
        val value = runCatching { JSONObject(raw) }.getOrNull() ?: return
        val privacy = value.optInt("privacy", 0)
        val name = value.optString("name").takeIf { it.isNotBlank() }
        val amount = value.optString("amount").takeIf { it.isNotBlank() }
        val russian = Locale.getDefault().language == "ru"
        val body = when (privacy) {
            1 -> if (russian) "Напоминание: $name" else "Reminder: $name"
            2 -> if (russian) "Напоминание: $name · $amount" else "Reminder: $name · $amount"
            else -> if (russian) "У вас есть напоминание Localhold" else "You have a Localhold reminder"
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    if (russian) "Напоминания Localhold" else "Localhold reminders",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val open = launch?.let {
            TaskStackBuilder.create(context).addNextIntentWithParentStack(it)
                .getPendingIntent(id.hashCode(), immutableFlags())
        }
        val snoozeIntent = Intent(context, LocalholdReminderSnoozeReceiver::class.java)
            .putExtra("id", id)
        val snooze = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            snoozeIntent,
            immutableFlags(),
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("Localhold")
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .addAction(0, if (russian) "Отложить" else "Snooze", snooze)
            .build()
        manager.notify(id.hashCode(), notification)
    }

    fun snooze(context: Context, id: String) {
        if (!idPattern.matches(id)) return
        val at = System.currentTimeMillis() + 10 * 60 * 1000L
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(id, null) ?: return
        val updated = runCatching { JSONObject(raw).put("at", at).toString() }.getOrNull() ?: return
        prefs.edit().putString(id, updated).apply()
        schedule(context, id, at)
    }

    private fun valid(value: SafeReminderRequest): Boolean {
        if (!idPattern.matches(value.syntheticId) || value.utcEpochMilliseconds <= System.currentTimeMillis()) return false
        if (value.privacyCode !in 0L..2L || (value.safeName?.length ?: 0) > 256 ||
            (value.safeAmount?.length ?: 0) > 64) return false
        return when (value.privacyCode) {
            0L -> value.safeName == null && value.safeAmount == null
            1L -> !value.safeName.isNullOrBlank() && value.safeAmount == null
            2L -> !value.safeName.isNullOrBlank() && !value.safeAmount.isNullOrBlank()
            else -> false
        }
    }

    private fun schedule(context: Context, id: String, at: Long) {
        alarm(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context, id))
    }

    private fun alarm(context: Context) = context.getSystemService(AlarmManager::class.java)
    private fun pending(context: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        context,
        id.hashCode(),
        Intent(context, LocalholdReminderReceiver::class.java).putExtra("id", id),
        immutableFlags(),
    )

    private fun immutableFlags() = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
}

class LocalholdReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        intent.getStringExtra("id")?.let { AndroidReminderStore.notify(context, it) }
    }
}

class LocalholdReminderSnoozeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        intent.getStringExtra("id")?.let { AndroidReminderStore.snooze(context, it) }
    }
}

class LocalholdReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AndroidReminderStore.restore(context)
    }
}

internal object AndroidInboundShareStore {
    private const val DIRECTORY = "localhold_inbound_share_v1"
    private const val INLINE_MAX = 64 * 1024L
    private const val FILE_MAX = 256 * 1024 * 1024L
    private const val TTL = 24 * 60 * 60 * 1000L
    private val idPattern = Regex("^[A-Za-z0-9_-]{22}$")

    fun stage(context: Context, intent: Intent): Boolean {
        val now = System.currentTimeMillis()
        val id = randomId()
        val directory = directory(context).apply { mkdirs() }
        val payload = File(directory, "$id.payload")
        val metadataFile = File(directory, "$id.json")
        return try {
            val mime = intent.type.orEmpty()
            val stream = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            val kind: ShareKindCode
            if (stream != null) {
                kind = if (mime.startsWith("image/")) ShareKindCode.IMAGE else ShareKindCode.FILE
                context.contentResolver.openInputStream(stream)?.use { input ->
                    payload.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var total = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            total += read
                            if (total > FILE_MAX) throw IllegalArgumentException("oversized")
                            output.write(buffer, 0, read)
                        }
                    }
                } ?: return false
            } else {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return false
                val bytes = text.encodeToByteArray()
                if (bytes.isEmpty() || bytes.size > INLINE_MAX) return false
                kind = if (isHttpUrl(text)) ShareKindCode.URL else ShareKindCode.TEXT
                payload.writeBytes(bytes)
                bytes.fill(0)
            }
            if (payload.length() !in 1..FILE_MAX) throw IllegalArgumentException("empty")
            val metadata = JSONObject()
                .put("id", id)
                .put("kind", kind.raw)
                .put("bytes", payload.length())
                .put("received", now)
                .put("expires", now + TTL)
            metadataFile.writeText(metadata.toString())
            true
        } catch (_: Throwable) {
            payload.delete()
            metadataFile.delete()
            false
        }
    }

    fun list(context: Context): InboundShareListReply = try {
        purge(context, System.currentTimeMillis())
        val items = directory(context).listFiles { file -> file.extension == "json" }.orEmpty()
            .mapNotNull { decode(it) }
        InboundShareListReply(items)
    } catch (_: Throwable) {
        InboundShareListReply(emptyList(), PlatformFeatureErrorCode.INTERNAL_FAILURE)
    }

    fun read(context: Context, request: InboundShareChunkRequest): InboundShareChunkReply = try {
        if (!idPattern.matches(request.id) || request.offset < 0 || request.maximumBytes !in 1..64 * 1024) {
            return chunkFailure(PlatformFeatureErrorCode.INVALID_REQUEST)
        }
        val file = File(directory(context), "${request.id}.payload")
        if (!file.isFile || request.offset > file.length()) return chunkFailure(PlatformFeatureErrorCode.NOT_FOUND)
        RandomAccessFile(file, "r").use { input ->
            input.seek(request.offset)
            val wanted = minOf(request.maximumBytes.toInt(), (file.length() - request.offset).toInt())
            val bytes = ByteArray(wanted)
            input.readFully(bytes)
            InboundShareChunkReply(bytes, request.offset + wanted == file.length())
        }
    } catch (_: Throwable) {
        chunkFailure(PlatformFeatureErrorCode.INTERNAL_FAILURE)
    }

    fun delete(context: Context, id: String): FeatureStatusReply = try {
        if (!idPattern.matches(id)) return FeatureStatusReply(PlatformFeatureErrorCode.INVALID_REQUEST)
        File(directory(context), "$id.payload").delete()
        File(directory(context), "$id.json").delete()
        FeatureStatusReply()
    } catch (_: Throwable) {
        FeatureStatusReply(PlatformFeatureErrorCode.INTERNAL_FAILURE)
    }

    fun purge(context: Context, now: Long): FeatureStatusReply = try {
        directory(context).listFiles { file -> file.extension == "json" }.orEmpty().forEach { file ->
            val value = decode(file)
            if (value == null || value.expiresUtcEpochMilliseconds <= now) {
                file.delete()
                File(file.parentFile, "${file.nameWithoutExtension}.payload").delete()
            }
        }
        FeatureStatusReply()
    } catch (_: Throwable) {
        FeatureStatusReply(PlatformFeatureErrorCode.INTERNAL_FAILURE)
    }

    private fun decode(file: File): InboundShareDescriptorReply? = runCatching {
        val value = JSONObject(file.readText())
        val id = value.getString("id")
        if (!idPattern.matches(id) || file.nameWithoutExtension != id) return null
        val kind = ShareKindCode.ofRaw(value.getLong("kind").toInt()) ?: return null
        val payload = File(file.parentFile, "$id.payload")
        val length = value.getLong("bytes")
        if (!payload.isFile || payload.length() != length) return null
        InboundShareDescriptorReply(
            id, kind, length, value.getLong("received"), value.getLong("expires"),
        )
    }.getOrNull()

    private fun directory(context: Context) = File(context.filesDir, DIRECTORY)
    private fun randomId(): String {
        val bytes = ByteArray(16).also { SecureRandom().nextBytes(it) }
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }
    private fun isHttpUrl(value: String): Boolean = runCatching {
        URI(value.trim()).scheme?.lowercase() in setOf("http", "https")
    }.getOrDefault(false)
    private fun chunkFailure(error: PlatformFeatureErrorCode) =
        InboundShareChunkReply(ByteArray(0), true, error)
}

class LocalholdInboundShareActivity : Activity() {
    override fun onCreate(state: android.os.Bundle?) {
        super.onCreate(state)
        if (intent?.action == Intent.ACTION_SEND) AndroidInboundShareStore.stage(this, intent)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(it)
        }
        finish()
    }
}

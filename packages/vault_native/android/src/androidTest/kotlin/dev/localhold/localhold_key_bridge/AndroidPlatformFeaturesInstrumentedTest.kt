// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import android.content.Context
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.util.Base64
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidPlatformFeaturesInstrumentedTest {
    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun reminderTimezoneAndShortcutBoundariesWorkOnDevice() = runBlocking {
        val features = AndroidPlatformFeatures(context)
        assertNull(features.notificationPermissionStatus().error)

        val gap = features.resolveWallClock(
            WallClockRequest(2026, 3, 29, 2, 30, "Europe/Berlin"),
        )
        assertEquals(WallClockResolutionCode.GAP_ADJUSTED, gap.resolution)
        assertNull(gap.error)

        val reminderId = opaqueId(1)
        val scheduled = features.replaceReminder(
            SafeReminderRequest(
                reminderId,
                System.currentTimeMillis() + 5 * 60 * 1000,
                0,
            ),
        )
        assertNull(scheduled.error)
        assertNull(features.cancelReminder(reminderId).error)

        assertEquals(
            PlatformFeatureErrorCode.PLATFORM_UNAVAILABLE,
            features.installLauncherShortcuts().error,
        )
        val actions = listOf(
            AndroidPlatformFeatures.ACTION_ADD to 1L,
            AndroidPlatformFeatures.ACTION_SEARCH to 2L,
            AndroidPlatformFeatures.ACTION_LOCK to 3L,
        )
        for ((action, expectedCode) in actions) {
            assertTrue(features.consumeIntent(Intent(action)))
            assertEquals(expectedCode, features.consumeLauncherAction().actionCode)
            assertEquals(0L, features.consumeLauncherAction().actionCode)
        }
        assertFalse(features.consumeIntent(Intent("dev.localhold.action.REVEAL")))
    }

    @Test
    fun inboundShareIsBoundedStreamedAndDeletedOnDevice() {
        assertNull(AndroidInboundShareStore.purge(context, Long.MAX_VALUE).error)
        val expected = "d08-share-fixture".encodeToByteArray()
        val intent = Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, expected.decodeToString())
        assertTrue(AndroidInboundShareStore.stage(context, intent))

        val descriptor = AndroidInboundShareStore.list(context).items.single()
        assertEquals(expected.size.toLong(), descriptor.byteLength)
        val first = AndroidInboundShareStore.read(
            context,
            InboundShareChunkRequest(descriptor.id, 0, 7),
        )
        val second = AndroidInboundShareStore.read(
            context,
            InboundShareChunkRequest(descriptor.id, 7, 64 * 1024),
        )
        assertFalse(first.done)
        assertTrue(second.done)
        assertArrayEquals(expected, first.bytes + second.bytes)
        assertNull(AndroidInboundShareStore.delete(context, descriptor.id).error)
        assertTrue(AndroidInboundShareStore.list(context).items.isEmpty())

        val oversized = "x".repeat(64 * 1024 + 1)
        assertFalse(
            AndroidInboundShareStore.stage(
                context,
                Intent(Intent.ACTION_SEND)
                    .setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, oversized),
            ),
        )
        assertTrue(AndroidInboundShareStore.list(context).items.isEmpty())

        repeat(8) { index ->
            assertTrue(
                AndroidInboundShareStore.stage(
                    context,
                    Intent(Intent.ACTION_SEND)
                        .setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, "queue-$index"),
                ),
            )
        }
        assertFalse(
            AndroidInboundShareStore.stage(
                context,
                Intent(Intent.ACTION_SEND)
                    .setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, "queue-overflow"),
            ),
        )
        assertEquals(8, AndroidInboundShareStore.list(context).items.size)
        assertNull(AndroidInboundShareStore.purge(context, Long.MAX_VALUE).error)

        val orphan = File(context.filesDir, "localhold_inbound_share_v1/orphan.payload")
        orphan.writeText("orphan")
        assertTrue(orphan.isFile)
        assertNull(AndroidInboundShareStore.purge(context, System.currentTimeMillis()).error)
        assertFalse(orphan.exists())
    }

    private fun opaqueId(fill: Byte): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(16) { fill })
}

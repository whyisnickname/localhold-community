// SPDX-License-Identifier: MPL-2.0
package dev.localhold.localhold_key_bridge

import kotlin.test.Test
import kotlin.test.assertEquals

internal class AndroidPlatformFeaturesTest {
    @Test
    fun `DST gap advances and overlap chooses the earlier occurrence`() {
        val gap = AndroidWallClockResolver.resolve(
            WallClockRequest(2026, 3, 29, 2, 30, "Europe/Berlin"),
        )
        val overlap = AndroidWallClockResolver.resolve(
            WallClockRequest(2026, 10, 25, 2, 30, "Europe/Berlin"),
        )

        assertEquals(WallClockResolutionCode.GAP_ADJUSTED, gap.resolution)
        assertEquals(WallClockResolutionCode.EARLIER, overlap.resolution)
        assertEquals(null, gap.error)
        assertEquals(null, overlap.error)
    }

    @Test
    fun `unknown timezone fails closed`() {
        val value = AndroidWallClockResolver.resolve(
            WallClockRequest(2026, 1, 1, 9, 0, "Unknown/Zone"),
        )

        assertEquals(PlatformFeatureErrorCode.INVALID_REQUEST, value.error)
    }
}

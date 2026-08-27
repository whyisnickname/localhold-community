// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PersistedGrantPolicyTest {
    @Test
    fun acceptsOnlyPersistableReadWriteGrant() {
        val readWrite =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        val complete = readWrite or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION

        assertEquals(readWrite, PersistedGrantPolicy.takeFlagsOrNull(complete))
        assertNull(
            PersistedGrantPolicy.takeFlagsOrNull(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            ),
        )
        assertNull(
            PersistedGrantPolicy.takeFlagsOrNull(
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            ),
        )
        assertNull(PersistedGrantPolicy.takeFlagsOrNull(readWrite))
    }
}

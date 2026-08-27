// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import android.content.Intent

object PersistedGrantPolicy {
    private const val REQUIRED =
        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    fun takeFlagsOrNull(resultFlags: Int): Int? {
        val hasReadAndWrite = resultFlags and REQUIRED == REQUIRED
        val isPersistable =
            resultFlags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0
        return if (hasReadAndWrite && isPersistable) REQUIRED else null
    }
}

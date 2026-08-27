// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import android.content.Context
import android.net.Uri

/** Local-only opaque SAF grant. Never include this value in network payloads. */
class BackupLocationStore(private val context: Context) {
    private val preferences = context.getSharedPreferences("backup_schedule", Context.MODE_PRIVATE)

    fun save(uri: Uri): Boolean =
        preferences.edit().putString("tree_uri", uri.toString()).commit()

    fun currentGrant(): Uri? {
        val raw = preferences.getString("tree_uri", null) ?: return null
        val uri = Uri.parse(raw)
        val persisted = context.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        return if (persisted) uri else null
    }
}

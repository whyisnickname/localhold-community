// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

enum class BackupDiagnosticCommand {
    CANCEL_SCHEDULE,
    RELEASE_LOCATION;

    companion object {
        const val ACTION_CANCEL_SCHEDULE =
            "dev.localhold.backup.spike.action.CANCEL_SCHEDULE"
        const val ACTION_RELEASE_LOCATION =
            "dev.localhold.backup.spike.action.RELEASE_LOCATION"

        fun parse(action: String?): BackupDiagnosticCommand? = when (action) {
            ACTION_CANCEL_SCHEDULE -> CANCEL_SCHEDULE
            ACTION_RELEASE_LOCATION -> RELEASE_LOCATION
            else -> null
        }
    }
}

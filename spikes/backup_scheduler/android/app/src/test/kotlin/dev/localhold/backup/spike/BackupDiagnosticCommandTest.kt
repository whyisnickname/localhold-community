// SPDX-License-Identifier: MPL-2.0
package dev.localhold.backup.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BackupDiagnosticCommandTest {
    @Test
    fun exactActionsAreRecognized() {
        assertEquals(
            BackupDiagnosticCommand.CANCEL_SCHEDULE,
            BackupDiagnosticCommand.parse(BackupDiagnosticCommand.ACTION_CANCEL_SCHEDULE),
        )
        assertEquals(
            BackupDiagnosticCommand.RELEASE_LOCATION,
            BackupDiagnosticCommand.parse(BackupDiagnosticCommand.ACTION_RELEASE_LOCATION),
        )
    }

    @Test
    fun absentOrSimilarActionsFailClosed() {
        assertNull(BackupDiagnosticCommand.parse(null))
        assertNull(BackupDiagnosticCommand.parse("dev.localhold.backup.CANCEL"))
        assertNull(
            BackupDiagnosticCommand.parse(
                "${BackupDiagnosticCommand.ACTION_CANCEL_SCHEDULE}.suffix",
            ),
        )
    }
}

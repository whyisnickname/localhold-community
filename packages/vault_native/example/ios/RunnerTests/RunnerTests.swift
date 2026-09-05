// SPDX-License-Identifier: MPL-2.0

import Foundation
import XCTest
@testable import localhold_vault_native

final class RunnerTests: XCTestCase {
  func testD08WallClockAndShortcutAllowlist() {
    let features = IOSPlatformFeatures()
    let gap = features.resolveWallClock(WallClockRequest(
      year: 2026,
      month: 3,
      day: 29,
      hour: 2,
      minute: 30,
      timeZoneId: "Europe/Berlin"
    ))
    XCTAssertEqual(gap.resolution, .gapAdjusted)
    XCTAssertNil(gap.error)

    XCTAssertFalse(features.acceptLauncherShortcut("localhold.reveal"))
    XCTAssertTrue(features.acceptLauncherShortcut("localhold.lock"))
    XCTAssertEqual(features.consumeLauncherAction().action, .lock)
    XCTAssertEqual(features.consumeLauncherAction().action, .none)
  }

  func testD08InlineShareLimitsFailBeforeFilesystemAccess() {
    XCTAssertFalse(IOSInboundShareStager.stageData(Data(), kind: .text))
    XCTAssertFalse(
      IOSInboundShareStager.stageData(Data(count: 64 * 1024 + 1), kind: .url)
    )
  }
}

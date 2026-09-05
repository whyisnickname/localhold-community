// SPDX-License-Identifier: MPL-2.0

import XCTest
@testable import localhold_key_bridge

final class IOSPlatformFeaturesTests: XCTestCase {
  func testDSTGapAndOverlapAreExplicit() {
    let features = IOSPlatformFeatures()
    let gap = features.resolveWallClock(WallClockRequest(
      year: 2026, month: 3, day: 29, hour: 2, minute: 30, timeZoneId: "Europe/Berlin"
    ))
    let overlap = features.resolveWallClock(WallClockRequest(
      year: 2026, month: 10, day: 25, hour: 2, minute: 30, timeZoneId: "Europe/Berlin"
    ))

    XCTAssertEqual(gap.resolution, .gapAdjusted)
    XCTAssertEqual(overlap.resolution, .earlier)
    XCTAssertNil(gap.error)
    XCTAssertNil(overlap.error)
  }

  func testMalformedSyntheticIdentifierFailsClosed() {
    let result = IOSPlatformFeatures().cancelReminder("record-name-or-secret")
    XCTAssertEqual(result.error, .invalidRequest)
  }

  func testLauncherShortcutAllowlistRejectsUnknownTypes() {
    let features = IOSPlatformFeatures()
    XCTAssertFalse(features.acceptLauncherShortcut("localhold.reveal"))
    XCTAssertTrue(features.acceptLauncherShortcut("localhold.search"))
    XCTAssertEqual(features.consumeLauncherAction().action, .search)
    XCTAssertEqual(features.consumeLauncherAction().action, .none)
  }
}

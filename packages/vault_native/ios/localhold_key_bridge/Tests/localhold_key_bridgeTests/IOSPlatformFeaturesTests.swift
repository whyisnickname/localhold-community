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
    XCTAssertEqual(features.consumeLauncherAction().actionCode, 2)
    XCTAssertEqual(features.consumeLauncherAction().actionCode, 0)
  }

  func testInboundShareRoundTripUsesBoundedChunksAndCleanup() {
    let store = IOSInboundShareStore()
    XCTAssertNil(store.purge(Int64.max).error)
    let expected = Data("d08-share-fixture".utf8)
    XCTAssertTrue(IOSInboundShareStager.stageData(expected, kind: .text))

    let descriptor = store.list().items.first
    XCTAssertNotNil(descriptor)
    guard let descriptor else { return }
    let first = store.read(InboundShareChunkRequest(
      id: descriptor.id,
      offset: 0,
      maximumBytes: 7
    ))
    let second = store.read(InboundShareChunkRequest(
      id: descriptor.id,
      offset: 7,
      maximumBytes: 65536
    ))
    XCTAssertFalse(first.done)
    XCTAssertTrue(second.done)
    XCTAssertEqual(first.bytes.data + second.bytes.data, expected)
    XCTAssertNil(store.delete(descriptor.id).error)
    XCTAssertTrue(store.list().items.isEmpty)
    XCTAssertFalse(IOSInboundShareStager.stageData(Data(count: 65537), kind: .text))
  }
}

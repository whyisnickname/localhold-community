// SPDX-License-Identifier: MPL-2.0

import Foundation
import XCTest
@testable import localhold_vault_native

private final class LockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
}

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
    XCTAssertEqual(features.consumeLauncherAction().actionCode, 3)
    XCTAssertEqual(features.consumeLauncherAction().actionCode, 0)
  }

  func testD08InlineShareLimitsFailBeforeFilesystemAccess() {
    XCTAssertFalse(IOSInboundShareStager.stageData(Data(), kind: .text))
    XCTAssertFalse(
      IOSInboundShareStager.stageData(Data(count: 64 * 1024 + 1), kind: .url)
    )
  }

  func testD08ConcurrentShareIntakeCannotExceedQueueBound() {
    let store = IOSInboundShareStore()
    XCTAssertNil(store.purge(Int64.max).error)
    let accepted = LockedCounter()
    DispatchQueue.concurrentPerform(iterations: 16) { index in
      let payload = Data(repeating: UInt8(index), count: 64 * 1024)
      if IOSInboundShareStager.stageData(payload, kind: .text) {
        accepted.increment()
      }
    }
    XCTAssertGreaterThan(accepted.value, 0)
    XCTAssertLessThanOrEqual(accepted.value, 8)
    XCTAssertEqual(store.list().items.count, accepted.value)
    XCTAssertNil(store.purge(Int64.max).error)
  }
}

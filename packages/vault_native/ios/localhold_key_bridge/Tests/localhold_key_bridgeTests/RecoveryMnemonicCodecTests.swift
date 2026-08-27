// SPDX-License-Identifier: MPL-2.0

import XCTest
@testable import localhold_key_bridge

final class RecoveryMnemonicCodecTests: XCTestCase {
  func testOfficialAllZeroAndAllOneVectorsRoundTrip() throws {
    let codec = try RecoveryMnemonicCodec()
    let zero = Data(repeating: 0, count: 32)
    let one = Data(repeating: 0xff, count: 32)
    let zeroPhrase = try codec.encode(zero)
    let onePhrase = try codec.encode(one)

    XCTAssertEqual(zeroPhrase, Array(repeating: "abandon", count: 23) + ["art"])
    XCTAssertEqual(onePhrase, Array(repeating: "zoo", count: 23) + ["vote"])
    XCTAssertEqual(try codec.decode(zeroPhrase), zero)
    XCTAssertEqual(try codec.decode(onePhrase), one)
  }

  func testChecksumUnknownWordAndWrongLengthFailClosed() throws {
    let codec = try RecoveryMnemonicCodec()
    var phrase = try codec.encode(Data(repeating: 0, count: 32))
    phrase[23] = "zoo"
    XCTAssertThrowsError(try codec.decode(phrase))
    phrase[23] = "notaword"
    XCTAssertThrowsError(try codec.decode(phrase))
    XCTAssertThrowsError(try codec.decode(Array(phrase.dropLast())))
  }
}

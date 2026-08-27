// SPDX-License-Identifier: MPL-2.0

import Foundation

guard CommandLine.arguments.count == 2 else {
  fatalError("wordlist path is required")
}
let source = try String(
  contentsOfFile: CommandLine.arguments[1],
  encoding: .utf8
)
let words = source.split(whereSeparator: \Character.isWhitespace).map(String.init)
let codec = try RecoveryMnemonicCodec(words: words)
let zero = Data(repeating: 0, count: 32)
let one = Data(repeating: 0xff, count: 32)
let zeroPhrase = try codec.encode(zero)
let onePhrase = try codec.encode(one)

precondition(zeroPhrase == Array(repeating: "abandon", count: 23) + ["art"])
precondition(onePhrase == Array(repeating: "zoo", count: 23) + ["vote"])
let decodedZero = try codec.decode(zeroPhrase)
let decodedOne = try codec.decode(onePhrase)
precondition(decodedZero == zero)
precondition(decodedOne == one)

var tampered = zeroPhrase
tampered[23] = "zoo"
do {
  _ = try codec.decode(tampered)
  fatalError("checksum tampering was accepted")
} catch RecoveryMnemonicFailure.invalidPhrase {
  // Expected closed failure.
}

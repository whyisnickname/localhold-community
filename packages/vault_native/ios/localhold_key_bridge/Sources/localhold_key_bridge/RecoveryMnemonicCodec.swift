// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation

/// BIP-39 entropy/checksum/index encoding only; wallet seed derivation is absent.
final class RecoveryMnemonicCodec {
  private let words: [String]
  private let indices: [String: Int]

  convenience init() throws {
    guard let url = Self.wordListURL(),
          let source = try? String(contentsOf: url, encoding: .utf8)
    else { throw RecoveryMnemonicFailure.invalidWordList }
    let candidate = source.split(whereSeparator: \Character.isWhitespace).map(String.init)
    try self.init(words: candidate)
  }

  init(words candidate: [String]) throws {
    guard candidate.count == 2048,
          Set(candidate).count == candidate.count,
          candidate == candidate.sorted(),
          candidate.allSatisfy({ $0.range(of: "^[a-z]+$", options: .regularExpression) != nil })
    else { throw RecoveryMnemonicFailure.invalidWordList }
    words = candidate
    indices = Dictionary(uniqueKeysWithValues: candidate.enumerated().map { ($0.element, $0.offset) })
  }

  func encode(_ entropy: Data) throws -> [String] {
    guard entropy.count == 32 else { throw RecoveryMnemonicFailure.invalidEntropy }
    let checksum = Self.checksumByte(for: entropy)
    return try (0..<24).map { wordPosition in
      var index = 0
      for bitWithinWord in 0..<11 {
        let bitPosition = wordPosition * 11 + bitWithinWord
        let bit: Int
        if bitPosition < 256 {
          bit = Int((entropy[bitPosition / 8] >> UInt8(7 - bitPosition % 8)) & 1)
        } else {
          bit = Int((checksum >> UInt8(7 - (bitPosition - 256))) & 1)
        }
        index = (index << 1) | bit
      }
      guard words.indices.contains(index) else { throw RecoveryMnemonicFailure.invalidEntropy }
      return words[index]
    }
  }

  func decode(_ input: [String]) throws -> Data {
    guard input.count == 24 else { throw RecoveryMnemonicFailure.invalidPhrase }
    var entropy = Data(repeating: 0, count: 32)
    var encodedChecksum = 0
    for (wordPosition, originalWord) in input.enumerated() {
      let word = originalWord.lowercased(with: Locale(identifier: "en_US_POSIX"))
      guard let index = indices[word] else { throw RecoveryMnemonicFailure.invalidPhrase }
      for bitWithinWord in 0..<11 {
        let bitPosition = wordPosition * 11 + bitWithinWord
        let bit = (index >> (10 - bitWithinWord)) & 1
        if bitPosition < 256 {
          let target = bitPosition / 8
          entropy[target] |= UInt8(bit << (7 - bitPosition % 8))
        } else {
          encodedChecksum = (encodedChecksum << 1) | bit
        }
      }
    }
    guard encodedChecksum == Int(Self.checksumByte(for: entropy)) else {
      entropy.resetBytes(in: 0..<entropy.count)
      throw RecoveryMnemonicFailure.invalidPhrase
    }
    return entropy
  }

  private static func checksumByte(for entropy: Data) -> UInt8 {
    Data(SHA256.hash(data: entropy))[0]
  }

  private static func wordListURL() -> URL? {
#if SWIFT_PACKAGE
    return Bundle.module.url(forResource: "bip39_english", withExtension: "txt")
#else
    let frameworkBundle = Bundle(for: RecoveryMnemonicCodec.self)
    if let resourceBundleURL = frameworkBundle.url(
      forResource: "localhold_key_bridge_recovery",
      withExtension: "bundle"
    ), let resourceBundle = Bundle(url: resourceBundleURL) {
      return resourceBundle.url(forResource: "bip39_english", withExtension: "txt")
    }
    return frameworkBundle.url(forResource: "bip39_english", withExtension: "txt")
#endif
  }
}

enum RecoveryMnemonicFailure: Error {
  case invalidWordList
  case invalidEntropy
  case invalidPhrase
}

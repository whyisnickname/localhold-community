// SPDX-License-Identifier: MPL-2.0
import Foundation

private struct Vector {
    let id: String
    let passwordHex: String
    let expectedOutputSHA256: String
}

private let vectors = [
    Vector(
        id: "ascii",
        passwordHex: "6c6f63616c686f6c642d7374616765322d73796e7468657469632d70617373776f7264",
        expectedOutputSHA256: "39bf18e5fdc7044a024f188e65b6ab5b8f65a607748ee5dd0ae57e5521a8ee54"
    ),
    Vector(
        id: "cyrillic",
        passwordHex: "d09fd0b0d180d0bed0bbd18c",
        expectedOutputSHA256: "7f562246443ab55f21f3fa0aa68a6ce1b9593ea4ddf2aaa8eaf8ce0020afa2da"
    ),
    Vector(
        id: "emoji",
        passwordHex: "f09f94902070617373776f7264",
        expectedOutputSHA256: "387ddd614859bacb69ea6daf05e8b8fb18418fa5d5e24c6ab7b5f55467e48526"
    ),
    Vector(
        id: "nfc",
        passwordHex: "c3a9",
        expectedOutputSHA256: "d1b586a8de64f7e17a2ce6d65549c4e79f117c2035ed6dedd508cbaa2134e0cb"
    ),
    Vector(
        id: "nfd",
        passwordHex: "65cc81",
        expectedOutputSHA256: "ad6dd9d760c3f4a4fa9a33e67d13e800a4536ac977f2bb02ede98cd9d1792162"
    ),
]

private var salt = Array((1...16).map(UInt8.init))
defer { salt.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }

for vector in vectors {
    var password = vector.passwordHex.hexBytes
    defer {
        password.withUnsafeMutableBytes {
            $0.initializeMemory(as: UInt8.self, repeating: 0)
        }
    }
    let result = try IOSArgon2Calibration.runSynthetic(
        password: password,
        salt: salt,
        memoryKiB: 65_536,
        operations: 3,
        sampleCount: 1
    )
    guard result.outputSHA256 == vector.expectedOutputSHA256 else {
        fatalError("Argon2id UTF-8 vector mismatch: \(vector.id)")
    }
}

guard vectors[3].expectedOutputSHA256 != vectors[4].expectedOutputSHA256 else {
    fatalError("NFC and NFD vectors were normalized")
}

private func expectInvalid(
    password: [UInt8],
    salt: [UInt8],
    memoryKiB: Int = 65_536,
    operations: UInt64 = 3,
    sampleCount: Int = 1
) {
    do {
        _ = try IOSArgon2Calibration.runSynthetic(
            password: password,
            salt: salt,
            memoryKiB: memoryKiB,
            operations: operations,
            sampleCount: sampleCount
        )
        fatalError("unsafe Argon2 request was accepted")
    } catch IOSArgon2CalibrationError.invalidRequest {
        // Expected.
    } catch {
        fatalError("unsafe Argon2 request returned the wrong error: \(error)")
    }
}

expectInvalid(password: [], salt: salt)
expectInvalid(password: [UInt8](repeating: 0x41, count: 1_025), salt: salt)
expectInvalid(password: [0x41], salt: [UInt8](repeating: 0, count: 15))
expectInvalid(password: [0x41], salt: salt, memoryKiB: 32_768)
expectInvalid(password: [0x41], salt: salt, operations: 1)
expectInvalid(password: [0x41], salt: salt, sampleCount: 0)
expectInvalid(password: [0x41], salt: salt, sampleCount: 51)

let wrongPassword = try IOSArgon2Calibration.runSynthetic(
    password: Array("localhold-stage2-synthetic-passw0rd".utf8),
    salt: salt,
    memoryKiB: 65_536,
    operations: 3,
    sampleCount: 1
)
guard wrongPassword.outputSHA256 != vectors[0].expectedOutputSHA256 else {
    fatalError("wrong password unexpectedly derived the reference candidate")
}
print("iOS/macOS libsodium passed \(vectors.count) Localhold Argon2id UTF-8 vectors")

private extension String {
    var hexBytes: [UInt8] {
        precondition(count.isMultiple(of: 2))
        var output: [UInt8] = []
        output.reserveCapacity(count / 2)
        var index = startIndex
        while index < endIndex {
            let next = self.index(index, offsetBy: 2)
            output.append(UInt8(self[index..<next], radix: 16)!)
            index = next
        }
        return output
    }
}

// SPDX-License-Identifier: MPL-2.0
import Clibsodium
import Foundation

enum IOSArgon2CalibrationError: Error {
    case invalidRequest
    case platformUnavailable
    case derivationFailed
    case hashFailed
}

struct IOSArgon2CalibrationResult {
    let memoryKiB: Int
    let operations: UInt64
    let samplesNanoseconds: [UInt64]
    let outputSHA256: String
}

enum IOSArgon2Calibration {
    private static let allowedMemoryKiB = Set([65_536, 98_304, 131_072])
    private static let allowedOperations = Set<UInt64>([2, 3, 4])

    static func runSynthetic(
        password: [UInt8],
        salt: [UInt8],
        memoryKiB: Int,
        operations: UInt64,
        sampleCount: Int
    ) throws -> IOSArgon2CalibrationResult {
        guard !password.isEmpty,
              password.count <= 1_024,
              salt.count == Int(crypto_pwhash_SALTBYTES),
              allowedMemoryKiB.contains(memoryKiB),
              allowedOperations.contains(operations),
              (1...50).contains(sampleCount)
        else {
            throw IOSArgon2CalibrationError.invalidRequest
        }
        guard sodium_init() >= 0 else {
            throw IOSArgon2CalibrationError.platformUnavailable
        }

        var mutablePassword = password
        var mutableSalt = salt
        var output = [UInt8](repeating: 0, count: 32)
        let passwordCount = mutablePassword.count
        let outputCount = output.count
        defer {
            mutablePassword.withUnsafeMutableBytes { sodium_memzero($0.baseAddress, $0.count) }
            mutableSalt.withUnsafeMutableBytes { sodium_memzero($0.baseAddress, $0.count) }
            output.withUnsafeMutableBytes { sodium_memzero($0.baseAddress, $0.count) }
        }

        var samples = [UInt64]()
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let started = DispatchTime.now().uptimeNanoseconds
            let status = mutablePassword.withUnsafeBytes { passwordBytes in
                mutableSalt.withUnsafeBytes { saltBytes in
                    output.withUnsafeMutableBytes { outputBytes in
                        guard
                            let outputPointer = outputBytes
                                .bindMemory(to: UInt8.self).baseAddress,
                            let passwordPointer = passwordBytes
                                .bindMemory(to: CChar.self).baseAddress,
                            let saltPointer = saltBytes
                                .bindMemory(to: UInt8.self).baseAddress
                        else {
                            return Int32(-1)
                        }
                        return crypto_pwhash(
                            outputPointer,
                            UInt64(outputCount),
                            passwordPointer,
                            UInt64(passwordCount),
                            saltPointer,
                            operations,
                            memoryKiB * 1_024,
                            crypto_pwhash_ALG_ARGON2ID13
                        )
                    }
                }
            }
            guard status == 0 else {
                throw IOSArgon2CalibrationError.derivationFailed
            }
            samples.append(DispatchTime.now().uptimeNanoseconds - started)
        }

        var digest = [UInt8](repeating: 0, count: 32)
        defer {
            digest.withUnsafeMutableBytes { sodium_memzero($0.baseAddress, $0.count) }
        }
        let hashStatus = digest.withUnsafeMutableBytes { digestBytes in
            output.withUnsafeBytes { outputBytes in
                guard
                    let digestPointer = digestBytes
                        .bindMemory(to: UInt8.self).baseAddress,
                    let outputPointer = outputBytes
                        .bindMemory(to: UInt8.self).baseAddress
                else {
                    return Int32(-1)
                }
                return crypto_hash_sha256(
                    digestPointer,
                    outputPointer,
                    UInt64(outputCount)
                )
            }
        }
        guard hashStatus == 0 else {
            throw IOSArgon2CalibrationError.hashFailed
        }
        return IOSArgon2CalibrationResult(
            memoryKiB: memoryKiB,
            operations: operations,
            samplesNanoseconds: samples,
            outputSHA256: digest.map { String(format: "%02x", $0) }.joined()
        )
    }
}

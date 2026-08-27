// SPDX-License-Identifier: MPL-2.0
import CryptoKit
import Foundation

enum IOSMobileStressError: Error {
    case invalidRequest
    case malformedStorage
    case staleSession
    case locked
    case syntheticCancellation
    case syntheticStorageFull
    case nonceReuse
}

final class IOSRecordSearchSession {
    fileprivate let generation: UInt64

    fileprivate init(generation: UInt64) {
        self.generation = generation
    }
}

struct IOSRecordWriteResult {
    let recordCount: Int
    let storedBytes: UInt64
    let uniqueNonceCount: Int
    let ciphertextSHA256: String
}

struct IOSRecordUnlockResult {
    let session: IOSRecordSearchSession
    let indexedRecordCount: Int
    let tokenCount: Int
}

final class IOSEncryptedRecordBlobStore {
    private static let magic: UInt32 = 0x4c485242
    private static let version: UInt32 = 1
    private static let sentinel = Data("LOCALHOLD-PLAINTEXT-".utf8)
    private let storageURL: URL
    private let key: SymmetricKey
    private let nonceAllocator: IOSNonceAllocatorProtocol
    private var generation: UInt64 = 1
    private var currentIndex: [String: Set<String>]?

    init(
        storageURL: URL,
        keyBytes: Data,
        nonceAllocator: IOSNonceAllocatorProtocol
    ) throws {
        guard keyBytes.count == 32 else { throw IOSMobileStressError.invalidRequest }
        self.storageURL = storageURL
        key = SymmetricKey(data: keyBytes)
        self.nonceAllocator = nonceAllocator
    }

    func writeSynthetic(recordCount: Int) throws -> IOSRecordWriteResult {
        guard (1...10_000).contains(recordCount) else {
            throw IOSMobileStressError.invalidRequest
        }
        let temporaryURL = storageURL.appendingPathExtension("tmp")
        try? FileManager.default.removeItem(at: temporaryURL)
        FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: temporaryURL)
        var nonces = Set<Data>()
        var digest = SHA256()
        do {
            try handle.write(contentsOf: Self.uint32(Self.magic))
            try handle.write(contentsOf: Self.uint32(Self.version))
            try handle.write(contentsOf: Self.uint32(UInt32(recordCount)))
            for index in 0..<recordCount {
                let recordID = "record-" + String(format: "%05d", index)
                var plaintext = Data(
                    ("LOCALHOLD-PLAINTEXT-" + String(index) + " title-" + String(index) +
                     " username-" + String(index) + "@example.invalid tag-" +
                     String(index % 17) + " needle" + String(index)).utf8
                )
                defer { plaintext.resetBytes(in: plaintext.startIndex..<plaintext.endIndex) }
                let nonceData = try nonceAllocator.reserve().nonce
                guard nonces.insert(nonceData).inserted else {
                    throw IOSMobileStressError.nonceReuse
                }
                let nonce = try AES.GCM.Nonce(data: nonceData)
                let aad = Data(("localhold-record-v1|" + recordID).utf8)
                let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
                var ciphertextAndTag = sealed.ciphertext + sealed.tag
                defer {
                    ciphertextAndTag.resetBytes(
                        in: ciphertextAndTag.startIndex..<ciphertextAndTag.endIndex
                    )
                }
                let idBytes = Data(recordID.utf8)
                try handle.write(contentsOf: Self.uint16(UInt16(idBytes.count)))
                try handle.write(contentsOf: idBytes)
                try handle.write(contentsOf: nonceData)
                try handle.write(contentsOf: Self.uint32(UInt32(ciphertextAndTag.count)))
                try handle.write(contentsOf: ciphertextAndTag)
                digest.update(data: nonceData)
                digest.update(data: ciphertextAndTag)
            }
            try handle.synchronize()
            try handle.close()
            if FileManager.default.fileExists(atPath: storageURL.path) {
                _ = try FileManager.default.replaceItemAt(storageURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: storageURL)
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: storageURL.path)
            let bytes = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            return IOSRecordWriteResult(
                recordCount: recordCount,
                storedBytes: bytes,
                uniqueNonceCount: nonces.count,
                ciphertextSHA256: Data(digest.finalize()).hex
            )
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    func unlockAndBuildIndex() throws -> IOSRecordUnlockResult {
        let handle = try FileHandle(forReadingFrom: storageURL)
        var candidate: [String: Set<String>] = [:]
        var indexed = 0
        do {
            guard try Self.readUInt32(handle) == Self.magic,
                  try Self.readUInt32(handle) == Self.version
            else {
                throw IOSMobileStressError.malformedStorage
            }
            let count = Int(try Self.readUInt32(handle))
            guard (1...10_000).contains(count) else {
                throw IOSMobileStressError.malformedStorage
            }
            for _ in 0..<count {
                let idLength = Int(try Self.readUInt16(handle))
                guard (1...128).contains(idLength) else {
                    throw IOSMobileStressError.malformedStorage
                }
                let recordIDData = try Self.readExactly(handle, count: idLength)
                guard let recordID = String(data: recordIDData, encoding: .utf8) else {
                    throw IOSMobileStressError.malformedStorage
                }
                let nonceData = try Self.readExactly(handle, count: 12)
                let encryptedLength = Int(try Self.readUInt32(handle))
                guard (16...65_536).contains(encryptedLength) else {
                    throw IOSMobileStressError.malformedStorage
                }
                var encrypted = try Self.readExactly(handle, count: encryptedLength)
                var plaintext = Data()
                defer {
                    encrypted.resetBytes(in: encrypted.startIndex..<encrypted.endIndex)
                    plaintext.resetBytes(in: plaintext.startIndex..<plaintext.endIndex)
                }
                let ciphertext = encrypted.dropLast(16)
                let tag = encrypted.suffix(16)
                let box = try AES.GCM.SealedBox(
                    nonce: AES.GCM.Nonce(data: nonceData),
                    ciphertext: ciphertext,
                    tag: tag
                )
                plaintext = try AES.GCM.open(
                    box,
                    using: key,
                    authenticating: Data(("localhold-record-v1|" + recordID).utf8)
                )
                guard let decoded = String(data: plaintext, encoding: .utf8) else {
                    throw IOSMobileStressError.malformedStorage
                }
                for token in Self.tokens(decoded) {
                    candidate[token, default: []].insert(recordID)
                }
                indexed += 1
            }
            guard try handle.read(upToCount: 1)?.isEmpty != false else {
                throw IOSMobileStressError.malformedStorage
            }
            try handle.close()
        } catch {
            candidate.removeAll(keepingCapacity: false)
            try? handle.close()
            throw error
        }
        currentIndex?.removeAll(keepingCapacity: false)
        currentIndex = candidate
        return IOSRecordUnlockResult(
            session: IOSRecordSearchSession(generation: generation),
            indexedRecordCount: indexed,
            tokenCount: candidate.count
        )
    }

    func query(_ session: IOSRecordSearchSession, token: String) throws -> Set<String> {
        guard session.generation == generation else { throw IOSMobileStressError.staleSession }
        guard let index = currentIndex else { throw IOSMobileStressError.locked }
        return index[token.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] ?? []
    }

    func lock() {
        currentIndex?.removeAll(keepingCapacity: false)
        currentIndex = nil
        generation += 1
    }

    func containsPlaintextSentinel() throws -> Bool {
        let handle = try FileHandle(forReadingFrom: storageURL)
        defer { try? handle.close() }
        var carried = Data()
        while let next = try handle.read(upToCount: 65_536), !next.isEmpty {
            let combined = carried + next
            if combined.range(of: Self.sentinel) != nil { return true }
            carried = combined.suffix(max(0, Self.sentinel.count - 1))
        }
        return false
    }

    func corruptCiphertext(recordIndex: Int) throws {
        let handle = try FileHandle(forUpdating: storageURL)
        defer { try? handle.close() }
        guard try Self.readUInt32(handle) == Self.magic,
              try Self.readUInt32(handle) == Self.version
        else {
            throw IOSMobileStressError.malformedStorage
        }
        let count = Int(try Self.readUInt32(handle))
        guard (0..<count).contains(recordIndex) else {
            throw IOSMobileStressError.invalidRequest
        }
        for index in 0..<count {
            let idLength = Int(try Self.readUInt16(handle))
            try handle.seek(toOffset: handle.offsetInFile + UInt64(idLength + 12))
            let encryptedLength = Int(try Self.readUInt32(handle))
            let start = handle.offsetInFile
            if index == recordIndex {
                let target = start + UInt64(encryptedLength / 2)
                try handle.seek(toOffset: target)
                var value = try Self.readExactly(handle, count: 1)
                value[0] ^= 0x01
                try handle.seek(toOffset: target)
                try handle.write(contentsOf: value)
                try handle.synchronize()
                return
            }
            try handle.seek(toOffset: start + UInt64(encryptedLength))
        }
        throw IOSMobileStressError.malformedStorage
    }

    private static func tokens(_ value: String) -> Set<String> {
        Set(
            value.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 2 }
        )
    }

    private static func readExactly(_ handle: FileHandle, count: Int) throws -> Data {
        guard let data = try handle.read(upToCount: count), data.count == count else {
            throw IOSMobileStressError.malformedStorage
        }
        return data
    }

    private static func readUInt16(_ handle: FileHandle) throws -> UInt16 {
        let data = try readExactly(handle, count: 2)
        var value: UInt16 = 0
        _ = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }
        return UInt16(bigEndian: value)
    }

    private static func readUInt32(_ handle: FileHandle) throws -> UInt32 {
        let data = try readExactly(handle, count: 4)
        var value: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }
        return UInt32(bigEndian: value)
    }

    private static func uint16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }

    private static func uint32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}

struct IOSAttachmentStreamResult {
    let totalPlaintextBytes: UInt64
    let chunkCount: Int
    let uniqueNonceCount: Int
    let emittedBytes: UInt64
    let finalChunkBytes: Int
    let manifestSHA256: String
}

final class IOSDiagnosticTransactionalTarget {
    private let failAfterBytes: UInt64?
    private(set) var currentVersion = "previous-valid"
    private(set) var partialBytes: UInt64 = 0
    private(set) var promoted = false

    init(failAfterBytes: UInt64? = nil) {
        self.failAfterBytes = failAfterBytes
    }

    func begin() {
        partialBytes = 0
        promoted = false
    }

    func write(count: Int) throws {
        let next = partialBytes + UInt64(count)
        if let limit = failAfterBytes, next > limit {
            throw IOSMobileStressError.syntheticStorageFull
        }
        partialBytes = next
    }

    func promote(manifestSHA256: String) {
        currentVersion = manifestSHA256
        promoted = true
    }

    func abort() {
        partialBytes = 0
        promoted = false
    }
}

final class IOSAttachmentStreamHarness {
    private static let chunkBytes = 1_048_576
    private static let maximumBytes: UInt64 = 5 * 1_024 * 1_024 * 1_024
    private let key: SymmetricKey
    private let nonceAllocator: IOSNonceAllocatorProtocol

    init(keyBytes: Data, nonceAllocator: IOSNonceAllocatorProtocol) throws {
        guard keyBytes.count == 32 else { throw IOSMobileStressError.invalidRequest }
        key = SymmetricKey(data: keyBytes)
        self.nonceAllocator = nonceAllocator
    }

    func encryptSynthetic(
        totalPlaintextBytes: UInt64,
        target: IOSDiagnosticTransactionalTarget,
        cancelAfterChunks: Int? = nil,
        onChunk: ((Int) -> Void)? = nil
    ) throws -> IOSAttachmentStreamResult {
        guard totalPlaintextBytes <= Self.maximumBytes,
              cancelAfterChunks == nil || cancelAfterChunks! >= 0
        else {
            throw IOSMobileStressError.invalidRequest
        }
        target.begin()
        var nonces = Set<Data>()
        var manifest = SHA256()
        var processed: UInt64 = 0
        var chunkIndex = 0
        var finalChunkBytes = 0
        do {
            while processed < totalPlaintextBytes {
                if let cancel = cancelAfterChunks, chunkIndex >= cancel {
                    throw IOSMobileStressError.syntheticCancellation
                }
                let length = Int(min(UInt64(Self.chunkBytes), totalPlaintextBytes - processed))
                var plaintext = Data(repeating: UInt8(chunkIndex & 0xff), count: length)
                defer { plaintext.resetBytes(in: plaintext.startIndex..<plaintext.endIndex) }
                let nonceData = try nonceAllocator.reserve().nonce
                guard nonces.insert(nonceData).inserted else {
                    throw IOSMobileStressError.nonceReuse
                }
                let aad = Self.aad(index: chunkIndex, totalBytes: totalPlaintextBytes, length: length)
                let sealed = try AES.GCM.seal(
                    plaintext,
                    using: key,
                    nonce: AES.GCM.Nonce(data: nonceData),
                    authenticating: aad
                )
                try target.write(count: nonceData.count + 4 + sealed.ciphertext.count + sealed.tag.count)
                manifest.update(data: nonceData)
                manifest.update(data: aad)
                manifest.update(data: sealed.tag)
                manifest.update(data: Self.uint32(UInt32(length)))
                processed += UInt64(length)
                chunkIndex += 1
                finalChunkBytes = length
                onChunk?(chunkIndex)
            }
            let hash = Data(manifest.finalize()).hex
            target.promote(manifestSHA256: hash)
            return IOSAttachmentStreamResult(
                totalPlaintextBytes: processed,
                chunkCount: chunkIndex,
                uniqueNonceCount: nonces.count,
                emittedBytes: target.partialBytes,
                finalChunkBytes: finalChunkBytes,
                manifestSHA256: hash
            )
        } catch {
            target.abort()
            throw error
        }
    }

    func corruptedChunkFailsAuthentication() throws -> Bool {
        let nonce = try AES.GCM.Nonce(data: nonceAllocator.reserve().nonce)
        let aad = Self.aad(index: 0, totalBytes: 37, length: 37)
        let plaintext = Data((1...37).map(UInt8.init))
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
        var tag = sealed.tag
        tag[tag.startIndex] ^= 0x01
        let corrupted = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: sealed.ciphertext,
            tag: tag
        )
        do {
            _ = try AES.GCM.open(corrupted, using: key, authenticating: aad)
            return false
        } catch {
            return true
        }
    }

    private static func aad(index: Int, totalBytes: UInt64, length: Int) -> Data {
        var data = Data()
        data.append(uint32(1))
        data.append(Data("Localhold-stage2".utf8))
        data.append(withUnsafeBytes(of: UInt64(index).bigEndian) { Data($0) })
        data.append(withUnsafeBytes(of: totalBytes.bigEndian) { Data($0) })
        data.append(uint32(UInt32(length)))
        return data
    }

    private static func uint32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}

private extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

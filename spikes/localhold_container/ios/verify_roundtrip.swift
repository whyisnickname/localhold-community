// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation

private let syntheticKey = SymmetricKey(data: Data(repeating: 0x31, count: 32))
private let maxManifestBytes = 1_048_576
private let maxChunks = 100_000
private let maxPlaintextChunkBytes = 8 * 1024 * 1024
private let plaintextChunks = [
    Data(),
    Data("Localhold synthetic".utf8),
    Data((0..<4097).map { UInt8($0 & 0xff) }),
]

private struct ChunkMetadata: Codable, Equatable {
    let ciphertextSize: Int
    let id: String
    let plaintextSize: Int

    enum CodingKeys: String, CodingKey {
        case ciphertextSize = "ciphertext_size"
        case id
        case plaintextSize = "plaintext_size"
    }
}

private struct Manifest: Codable, Equatable {
    let algorithm: String
    let chunkCount: Int
    let chunks: [ChunkMetadata]
    let formatVersion: Int
    let plaintextSha256: String

    enum CodingKeys: String, CodingKey {
        case algorithm
        case chunkCount = "chunk_count"
        case chunks
        case formatVersion = "format_version"
        case plaintextSha256 = "plaintext_sha256"
    }
}

private enum ContainerError: Error {
    case truncated
    case unsupported
    case invalid
}

private func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

private func u32(_ value: Int) -> Data {
    precondition(value >= 0 && value <= Int(UInt32.max))
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}

private func chunkID(_ index: Int) -> String {
    String(format: "chunk-%08d", index)
}

private func nonce(for index: Int) throws -> AES.GCM.Nonce {
    var bytes = Data([0x4c, 0x48, 0x42, 0x31])
    var counter = UInt64(index).bigEndian
    withUnsafeBytes(of: &counter) { bytes.append(contentsOf: $0) }
    return try AES.GCM.Nonce(data: bytes)
}

private func aad(metadata: ChunkMetadata, index: Int, count: Int) -> Data {
    Data(
        "localhold-backup-v1:\(metadata.id):\(index):\(count):\(metadata.plaintextSize)".utf8
    )
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func encode(_ chunks: [Data]) throws -> Data {
    guard chunks.count <= maxChunks,
          chunks.allSatisfy({ $0.count <= maxPlaintextChunkBytes }) else {
        throw ContainerError.invalid
    }
    let metadata = chunks.enumerated().map { index, plaintext in
        ChunkMetadata(
            ciphertextSize: plaintext.count + 28,
            id: chunkID(index),
            plaintextSize: plaintext.count
        )
    }
    let combined = chunks.reduce(into: Data()) { $0.append($1) }
    let manifest = Manifest(
        algorithm: "AES-256-GCM",
        chunkCount: chunks.count,
        chunks: metadata,
        formatVersion: 1,
        plaintextSha256: sha256Hex(combined)
    )
    let manifestData = try canonicalJSON(manifest)
    guard manifestData.count <= maxManifestBytes else { throw ContainerError.invalid }
    var output = Data("LOCALH1\n".utf8)
    output.append(u32(manifestData.count))
    output.append(manifestData)
    for (index, plaintext) in chunks.enumerated() {
        let currentNonce = try nonce(for: index)
        let sealed = try AES.GCM.seal(
            plaintext,
            using: syntheticKey,
            nonce: currentNonce,
            authenticating: aad(metadata: metadata[index], index: index, count: chunks.count)
        )
        var chunk = Data(currentNonce)
        chunk.append(sealed.tag)
        chunk.append(sealed.ciphertext)
        precondition(chunk.count == metadata[index].ciphertextSize)
        output.append(u32(chunk.count))
        output.append(chunk)
    }
    return output
}

private struct Cursor {
    let data: Data
    var offset = 0

    mutating func take(_ count: Int) throws -> Data {
        guard count >= 0, offset <= data.count, count <= data.count - offset else {
            throw ContainerError.truncated
        }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func readU32() throws -> Int {
        let bytes = try take(4)
        return bytes.reduce(0) { ($0 << 8) | Int($1) }
    }
}

private func decode(_ container: Data) throws -> [Data] {
    var cursor = Cursor(data: container)
    guard try cursor.take(8) == Data("LOCALH1\n".utf8) else {
        throw ContainerError.unsupported
    }
    let manifestLength = try cursor.readU32()
    guard manifestLength <= maxManifestBytes else { throw ContainerError.invalid }
    let manifestData = try cursor.take(manifestLength)
    let manifest: Manifest
    do {
        manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
    } catch {
        throw ContainerError.invalid
    }
    guard try canonicalJSON(manifest) == manifestData,
          manifest.algorithm == "AES-256-GCM",
          manifest.formatVersion == 1,
          manifest.chunkCount >= 0,
          manifest.chunkCount <= maxChunks,
          manifest.chunks.count == manifest.chunkCount,
          manifest.plaintextSha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
        throw ContainerError.invalid
    }
    for (index, metadata) in manifest.chunks.enumerated() {
        guard metadata.id == chunkID(index),
              metadata.plaintextSize >= 0,
              metadata.plaintextSize <= maxPlaintextChunkBytes,
              metadata.ciphertextSize == metadata.plaintextSize + 28 else {
            throw ContainerError.invalid
        }
    }
    var plaintext: [Data] = []
    for (index, metadata) in manifest.chunks.enumerated() {
        let length = try cursor.readU32()
        guard length == metadata.ciphertextSize else { throw ContainerError.invalid }
        let chunk = try cursor.take(length)
        let nonceData = chunk.prefix(12)
        guard nonceData == Data(try nonce(for: index)) else {
            throw ContainerError.invalid
        }
        let box = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonceData),
            ciphertext: chunk.dropFirst(28),
            tag: chunk.dropFirst(12).prefix(16)
        )
        let clear = try AES.GCM.open(
            box,
            using: syntheticKey,
            authenticating: aad(metadata: metadata, index: index, count: manifest.chunkCount)
        )
        guard clear.count == metadata.plaintextSize else { throw ContainerError.invalid }
        plaintext.append(clear)
    }
    guard cursor.offset == container.count else { throw ContainerError.invalid }
    let combined = plaintext.reduce(into: Data()) { $0.append($1) }
    guard sha256Hex(combined) == manifest.plaintextSha256 else {
        throw ContainerError.invalid
    }
    return plaintext
}

let encoded = try encode(plaintextChunks)
precondition(encoded.count == 4581)
precondition(sha256Hex(encoded) == "ff1a6b6bbf7227034ba597b3090ff34a85c7c0ca73d7327db854df5ae5a458f5")
let decoded = try decode(encoded)
precondition(decoded == plaintextChunks)
let decodedEmpty = try decode(encode([]))
precondition(decodedEmpty.isEmpty)
let decodedSingleByte = try decode(encode([Data([0x7f])]))
precondition(decodedSingleByte == [Data([0x7f])])

var tampered = encoded
tampered[tampered.index(before: tampered.endIndex)] ^= 1
do {
    _ = try decode(tampered)
    fatalError("tampered container authenticated")
} catch {
    // Required failure.
}

print("Swift .localhold canonical round-trip passed (\(encoded.count) bytes).")

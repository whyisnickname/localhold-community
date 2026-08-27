// SPDX-License-Identifier: MPL-2.0

import Clibsodium
import CryptoKit
import Flutter
import Foundation
import Security

private let masterMagic: UInt32 = 0x4c484d31
private let payloadMagic: UInt32 = 0x4c485031
private let recoveryMagic: UInt32 = 0x4c485231
private let formatVersion: UInt8 = 1
private let kdfMemoryKiB = 98_304
private let kdfOperations: UInt64 = 3
private let dekBytes = 32
private let saltBytes = 16
private let keyGenerationBytes = 16
private let nonceBytes = 12
private let maximumPayloadBytes = 2 * 1024 * 1024
private let maximumAADBytes = 4 * 1024
private let masterEnvelopeBytes = 106
private let recoveryEnvelopeBytes = 81
private let masterFreshnessSeconds: UInt64 = 30 * 24 * 60 * 60
private let sensitiveSessionFreshnessSeconds: TimeInterval = 5 * 60

final class IOSVaultCryptoService {
  private let lock = NSLock()
  private var sessions: [String: IOSVaultSession] = [:]
  private var recoveryCeremonies: [String: IOSRecoveryCeremony] = [:]
  private let allocator = IOSDurableNonceAllocator()
  private let masterFreshness = IOSMasterCredentialFreshnessStore()
  private lazy var mnemonic: RecoveryMnemonicCodec? = try? RecoveryMnemonicCodec()

  func create(_ request: CreateVaultKeyRequest) -> VaultSessionReply {
    guardedSession {
      try requireVaultId(request.vaultId)
      var password = request.masterPassword.data
      defer { password.resetBytes(in: 0..<password.count) }
      try requirePassword(password)
      var dek = try secureRandom(count: dekBytes)
      var keyGeneration = try secureRandom(count: keyGenerationBytes)
      let salt = try secureRandom(count: saltBytes)
      var kek = try derive(password: password, salt: salt)
      defer {
        dek.resetBytes(in: 0..<dek.count)
        keyGeneration.resetBytes(in: 0..<keyGeneration.count)
        kek.resetBytes(in: 0..<kek.count)
      }
      try allocator.initialize(keyGeneration: keyGeneration)
      let envelope = try wrapMaster(
        vaultId: request.vaultId,
        dek: dek,
        keyGeneration: keyGeneration,
        salt: salt,
        kek: kek
      )
      let handle = try createSession(
        vaultId: request.vaultId,
        keyGeneration: keyGeneration,
        dek: dek,
        origin: .master
      )
      do {
        try masterFreshness.record(vaultId: request.vaultId)
      } catch {
        _ = close(handle)
        throw error
      }
      return VaultSessionReply(
        sessionHandle: handle,
        keyGenerationId: keyGeneration.base64URL,
        vaultKeyEnvelope: FlutterStandardTypedData(bytes: envelope)
      )
    }
  }

  func open(_ request: OpenVaultSessionRequest) -> VaultSessionReply {
    guardedSession {
      try requireVaultId(request.vaultId)
      var password = request.masterPassword.data
      defer { password.resetBytes(in: 0..<password.count) }
      try requirePassword(password)
      let parsed = try parseMasterEnvelope(request.vaultKeyEnvelope.data)
      try allocator.requirePresent(keyGeneration: parsed.keyGeneration)
      var kek = try derive(password: password, salt: parsed.salt)
      defer { kek.resetBytes(in: 0..<kek.count) }
      let aad = masterAad(vaultId: request.vaultId, keyGeneration: parsed.keyGeneration)
      var dek: Data
      do {
        dek = try openAesGcm(
          key: kek,
          nonce: parsed.nonce,
          ciphertextAndTag: parsed.wrappedDek,
          aad: aad
        )
      } catch {
        throw IOSBridgeFailure(.invalidCredentials)
      }
      defer { dek.resetBytes(in: 0..<dek.count) }
      let handle = try createSession(
        vaultId: request.vaultId,
        keyGeneration: parsed.keyGeneration,
        dek: dek,
        origin: .master
      )
      do {
        try masterFreshness.record(vaultId: request.vaultId)
      } catch {
        _ = close(handle)
        throw error
      }
      return VaultSessionReply(
        sessionHandle: handle,
        keyGenerationId: parsed.keyGeneration.base64URL
      )
    }
  }

  func encrypt(_ request: EncryptPayloadRequest) -> PayloadReply {
    guardedPayload {
      var plaintext = request.plaintext.data
      defer { plaintext.resetBytes(in: 0..<plaintext.count) }
      let aad = request.authenticatedData.data
      guard plaintext.count <= maximumPayloadBytes,
            !aad.isEmpty,
            aad.count <= maximumAADBytes
      else {
        throw IOSBridgeFailure(.payloadTooLarge)
      }
      let session = try requireSession(request.sessionHandle)
      let nonce = try allocator.reserve(keyGeneration: session.keyGeneration)
      let encrypted = try sealAesGcm(
        key: session.dek,
        nonce: nonce,
        plaintext: plaintext,
        aad: aad
      )
      var output = Data()
      output.appendBigEndian(payloadMagic)
      output.append(formatVersion)
      output.append(session.keyGeneration)
      output.append(nonce)
      output.append(encrypted)
      return PayloadReply(payload: FlutterStandardTypedData(bytes: output))
    }
  }

  func decrypt(_ request: DecryptPayloadRequest) -> PayloadReply {
    guardedPayload {
      let envelope = request.encryptedPayload.data
      let aad = request.authenticatedData.data
      guard envelope.count <= maximumPayloadBytes + 128,
            !aad.isEmpty,
            aad.count <= maximumAADBytes
      else {
        throw IOSBridgeFailure(.payloadTooLarge)
      }
      let session = try requireSession(request.sessionHandle)
      var cursor = DataCursor(envelope)
      guard try cursor.readUInt32() == payloadMagic,
            try cursor.readUInt8() == formatVersion
      else {
        throw IOSBridgeFailure(.unsupportedVersion)
      }
      let keyGeneration = try cursor.read(count: keyGenerationBytes)
      guard keyGeneration == session.keyGeneration else {
        throw IOSBridgeFailure(.integrityFailure)
      }
      let nonce = try cursor.read(count: nonceBytes)
      let ciphertext = try cursor.readRemaining(minimum: 16)
      do {
        let plaintext = try openAesGcm(
          key: session.dek,
          nonce: nonce,
          ciphertextAndTag: ciphertext,
          aad: aad
        )
        return PayloadReply(payload: FlutterStandardTypedData(bytes: plaintext))
      } catch {
        throw IOSBridgeFailure(.integrityFailure)
      }
    }
  }

  func rewrap(_ request: RewrapVaultKeyRequest) -> PayloadReply {
    guardedPayload {
      var password = request.newMasterPassword.data
      defer { password.resetBytes(in: 0..<password.count) }
      try requirePassword(password)
      let session = try requireSensitiveSession(request.sessionHandle)
      let salt = try secureRandom(count: saltBytes)
      var kek = try derive(password: password, salt: salt)
      defer { kek.resetBytes(in: 0..<kek.count) }
      let envelope = try wrapMaster(
        vaultId: session.vaultId,
        dek: session.dek,
        keyGeneration: session.keyGeneration,
        salt: salt,
        kek: kek
      )
      try masterFreshness.record(vaultId: session.vaultId)
      return PayloadReply(payload: FlutterStandardTypedData(bytes: envelope))
    }
  }

  func beginRecovery(_ sessionHandle: String) -> RecoveryCeremonyReply {
    do {
      let session = try requireSensitiveSession(sessionHandle)
      guard let mnemonic else { throw IOSBridgeFailure(.platformUnavailable) }
      var entropy = try secureRandom(count: dekBytes)
      let words = try mnemonic.encode(entropy)
      let nonce = try secureRandom(count: nonceBytes)
      let wrapped = try sealAesGcm(
        key: entropy,
        nonce: nonce,
        plaintext: session.dek,
        aad: recoveryAad(vaultId: session.vaultId, keyGeneration: session.keyGeneration)
      )
      var envelope = Data()
      envelope.appendBigEndian(recoveryMagic)
      envelope.append(formatVersion)
      envelope.append(session.keyGeneration)
      envelope.append(nonce)
      envelope.append(wrapped)
      let positions = try generateChallengePositions()
      let handle = try secureRandom(count: 16).base64URL
      lock.lock()
      recoveryCeremonies[handle] = IOSRecoveryCeremony(
        words: words,
        entropy: entropy,
        envelope: envelope,
        positions: positions
      )
      lock.unlock()
      entropy.resetBytes(in: 0..<entropy.count)
      envelope.resetBytes(in: 0..<envelope.count)
      return RecoveryCeremonyReply(
        ceremonyHandle: handle,
        challengePositions: positions.map { Int64($0 + 1) }
      )
    } catch let failure as IOSBridgeFailure {
      return RecoveryCeremonyReply(error: failure.code)
    } catch {
      return RecoveryCeremonyReply(error: .internalFailure)
    }
  }

  /// Native presentation only: this value must never be returned by Pigeon.
  func recoveryWordsForPresentation(_ ceremonyHandle: String) -> [String]? {
    lock.lock()
    let words = recoveryCeremonies[ceremonyHandle]?.words
    lock.unlock()
    return words
  }

  func confirmRecovery(_ request: ConfirmRecoveryKeyRequest) -> PayloadReply {
    guardedPayload {
      lock.lock()
      guard var ceremony = recoveryCeremonies[request.ceremonyHandle] else {
        lock.unlock()
        throw IOSBridgeFailure(.invalidRequest)
      }
      lock.unlock()
      var challengeBytes = request.challengeWordsUtf8.data
      defer { challengeBytes.resetBytes(in: 0..<challengeBytes.count) }
      let challengeWords = try parseRecoveryWords(
        challengeBytes,
        expectedWords: ceremony.positions.count
      )
      let valid = ceremony.positions.indices.allSatisfy { index in
        ceremony.words[ceremony.positions[index]].caseInsensitiveCompare(
          challengeWords[index]
        ) == .orderedSame
      }
      guard valid else { throw IOSBridgeFailure(.invalidCredentials) }
      lock.lock()
      recoveryCeremonies.removeValue(forKey: request.ceremonyHandle)
      lock.unlock()
      let output = ceremony.envelope
      ceremony.destroy()
      return PayloadReply(payload: FlutterStandardTypedData(bytes: output))
    }
  }

  func openRecovery(_ request: OpenVaultWithRecoveryRequest) -> VaultSessionReply {
    guardedSession {
      try requireVaultId(request.vaultId)
      guard let mnemonic else { throw IOSBridgeFailure(.platformUnavailable) }
      var recoveryBytes = request.recoveryPhraseUtf8.data
      defer { recoveryBytes.resetBytes(in: 0..<recoveryBytes.count) }
      var entropy: Data
      do {
        entropy = try mnemonic.decode(
          parseRecoveryWords(recoveryBytes, expectedWords: 24)
        )
      } catch {
        throw IOSBridgeFailure(.invalidCredentials)
      }
      defer { entropy.resetBytes(in: 0..<entropy.count) }
      let parsed = try parseRecoveryEnvelope(request.recoveryKeyEnvelope.data)
      try allocator.requirePresent(keyGeneration: parsed.keyGeneration)
      var dek: Data
      do {
        dek = try openAesGcm(
          key: entropy,
          nonce: parsed.nonce,
          ciphertextAndTag: parsed.wrappedDek,
          aad: recoveryAad(vaultId: request.vaultId, keyGeneration: parsed.keyGeneration)
        )
      } catch {
        throw IOSBridgeFailure(.invalidCredentials)
      }
      defer { dek.resetBytes(in: 0..<dek.count) }
      return VaultSessionReply(
        sessionHandle: try createSession(
          vaultId: request.vaultId,
          keyGeneration: parsed.keyGeneration,
          dek: dek,
          origin: .recovery
        ),
        keyGenerationId: parsed.keyGeneration.base64URL
      )
    }
  }

  func cancelRecovery(_ ceremonyHandle: String) -> StatusReply {
    lock.lock()
    var removed = recoveryCeremonies.removeValue(forKey: ceremonyHandle)
    lock.unlock()
    removed?.destroy()
    return StatusReply()
  }

  func biometricMaterial(_ sessionHandle: String) -> IOSBiometricMaterial? {
    lock.lock()
    let session = sessions[sessionHandle]
    lock.unlock()
    guard let session, isSensitiveSessionFresh(session) else { return nil }
    return IOSBiometricMaterial(
      vaultId: session.vaultId,
      keyGeneration: session.keyGeneration,
      dek: session.dek
    )
  }

  func sensitiveSessionError(_ sessionHandle: String) -> KeyBridgeErrorCode? {
    lock.lock()
    let session = sessions[sessionHandle]
    lock.unlock()
    guard let session else { return .sessionNotFound }
    return isSensitiveSessionFresh(session) ? nil : .reauthenticationRequired
  }

  func isMasterCredentialFresh(_ vaultId: String) -> Bool {
    masterFreshness.isFresh(vaultId: vaultId)
  }

  func openBiometric(
    vaultId: String,
    keyGeneration: Data,
    dek: Data
  ) -> VaultSessionReply {
    guardedSession {
      try requireVaultId(vaultId)
      guard keyGeneration.count == keyGenerationBytes, dek.count == dekBytes else {
        throw IOSBridgeFailure(.integrityFailure)
      }
      try allocator.requirePresent(keyGeneration: keyGeneration)
      return VaultSessionReply(
        sessionHandle: try createSession(
          vaultId: vaultId,
          keyGeneration: keyGeneration,
          dek: dek,
          origin: .biometric
        ),
        keyGenerationId: keyGeneration.base64URL
      )
    }
  }

  func close(_ handle: String) -> StatusReply {
    lock.lock()
    var removed = sessions.removeValue(forKey: handle)
    lock.unlock()
    removed?.destroy()
    return StatusReply()
  }

  func closeAll() -> StatusReply {
    lock.lock()
    let removed = sessions.values
    let removedCeremonies = recoveryCeremonies.values
    sessions.removeAll()
    recoveryCeremonies.removeAll()
    lock.unlock()
    removed.forEach { var session = $0; session.destroy() }
    removedCeremonies.forEach { var ceremony = $0; ceremony.destroy() }
    return StatusReply()
  }

  private func createSession(
    vaultId: String,
    keyGeneration: Data,
    dek: Data,
    origin: IOSSessionOrigin
  ) throws -> String {
    let handle = try secureRandom(count: 16).base64URL
    lock.lock()
    sessions[handle] = IOSVaultSession(
      vaultId: vaultId,
      keyGeneration: keyGeneration,
      dek: dek,
      origin: origin,
      credentialVerifiedAtUptime: ProcessInfo.processInfo.systemUptime
    )
    lock.unlock()
    return handle
  }

  private func requireSession(_ handle: String) throws -> IOSVaultSession {
    lock.lock()
    let session = sessions[handle]
    lock.unlock()
    guard let session else { throw IOSBridgeFailure(.sessionNotFound) }
    return session
  }

  private func requireSensitiveSession(_ handle: String) throws -> IOSVaultSession {
    let session = try requireSession(handle)
    guard isSensitiveSessionFresh(session) else {
      throw IOSBridgeFailure(.reauthenticationRequired)
    }
    return session
  }

  private func isSensitiveSessionFresh(_ session: IOSVaultSession) -> Bool {
    guard session.origin != .biometric else { return false }
    let elapsed = ProcessInfo.processInfo.systemUptime - session.credentialVerifiedAtUptime
    return elapsed >= 0 && elapsed <= sensitiveSessionFreshnessSeconds
  }

  private func derive(password: Data, salt: Data) throws -> Data {
    var output = Data(count: dekBytes)
    let result: Int32 = output.withUnsafeMutableBytes { outputBuffer in
      password.withUnsafeBytes { passwordBuffer in
        salt.withUnsafeBytes { saltBuffer in
          guard let outputAddress = outputBuffer.baseAddress,
                let passwordAddress = passwordBuffer.baseAddress,
                let saltAddress = saltBuffer.baseAddress
          else { return -1 }
          return crypto_pwhash(
            outputAddress.assumingMemoryBound(to: UInt8.self),
            UInt64(dekBytes),
            passwordAddress.assumingMemoryBound(to: CChar.self),
            UInt64(password.count),
            saltAddress.assumingMemoryBound(to: UInt8.self),
            kdfOperations,
            kdfMemoryKiB * 1024,
            crypto_pwhash_ALG_ARGON2ID13
          )
        }
      }
    }
    guard result == 0 else {
      output.resetBytes(in: 0..<output.count)
      throw IOSBridgeFailure(.platformUnavailable)
    }
    return output
  }

  private func wrapMaster(
    vaultId: String,
    dek: Data,
    keyGeneration: Data,
    salt: Data,
    kek: Data
  ) throws -> Data {
    let nonce = try secureRandom(count: nonceBytes)
    let wrapped = try sealAesGcm(
      key: kek,
      nonce: nonce,
      plaintext: dek,
      aad: masterAad(vaultId: vaultId, keyGeneration: keyGeneration)
    )
    var output = Data()
    output.appendBigEndian(masterMagic)
    output.append(formatVersion)
    output.appendBigEndian(UInt32(kdfMemoryKiB))
    output.appendBigEndian(UInt32(kdfOperations))
    output.append(1)
    output.append(salt)
    output.append(keyGeneration)
    output.append(nonce)
    output.append(wrapped)
    guard output.count == masterEnvelopeBytes else {
      throw IOSBridgeFailure(.internalFailure)
    }
    return output
  }

  private func parseMasterEnvelope(_ envelope: Data) throws -> IOSParsedMasterEnvelope {
    guard envelope.count == masterEnvelopeBytes else {
      throw IOSBridgeFailure(.invalidRequest)
    }
    var cursor = DataCursor(envelope)
    guard try cursor.readUInt32() == masterMagic,
          try cursor.readUInt8() == formatVersion,
          try cursor.readUInt32() == UInt32(kdfMemoryKiB),
          try cursor.readUInt32() == UInt32(kdfOperations),
          try cursor.readUInt8() == 1
    else {
      throw IOSBridgeFailure(.unsupportedVersion)
    }
    return IOSParsedMasterEnvelope(
      salt: try cursor.read(count: saltBytes),
      keyGeneration: try cursor.read(count: keyGenerationBytes),
      nonce: try cursor.read(count: nonceBytes),
      wrappedDek: try cursor.readRemaining(exact: 48)
    )
  }

  private func parseRecoveryEnvelope(_ envelope: Data) throws -> IOSParsedRecoveryEnvelope {
    guard envelope.count == recoveryEnvelopeBytes else {
      throw IOSBridgeFailure(.invalidRequest)
    }
    var cursor = DataCursor(envelope)
    guard try cursor.readUInt32() == recoveryMagic,
          try cursor.readUInt8() == formatVersion
    else { throw IOSBridgeFailure(.unsupportedVersion) }
    return IOSParsedRecoveryEnvelope(
      keyGeneration: try cursor.read(count: keyGenerationBytes),
      nonce: try cursor.read(count: nonceBytes),
      wrappedDek: try cursor.readRemaining(exact: 48)
    )
  }

  private func masterAad(vaultId: String, keyGeneration: Data) -> Data {
    Data("localhold.master-wrapper.v1|\(vaultId)|\(keyGeneration.base64URL)".utf8)
  }

  private func recoveryAad(vaultId: String, keyGeneration: Data) -> Data {
    Data("localhold.recovery-wrapper.v1|\(vaultId)|\(keyGeneration.base64URL)".utf8)
  }

  private func generateChallengePositions() throws -> [Int] {
    var positions = Set<Int>()
    while positions.count < 4 {
      let candidate = Int(try secureRandom(count: 1)[0])
      if candidate < 240 { positions.insert(candidate % 24) }
    }
    return positions.sorted()
  }

  private func requireVaultId(_ value: String) throws {
    let range = value.range(of: "^[A-Za-z0-9_-]{22}$", options: .regularExpression)
    guard range != nil else { throw IOSBridgeFailure(.invalidRequest) }
  }

  private func requirePassword(_ value: Data) throws {
    guard !value.isEmpty,
          value.count <= 1024,
          let decoded = String(data: value, encoding: .utf8),
          decoded.unicodeScalars.count >= 15
    else {
      throw IOSBridgeFailure(.invalidRequest)
    }
  }

  private func parseRecoveryWords(_ bytes: Data, expectedWords: Int) throws -> [String] {
    guard !bytes.isEmpty,
          bytes.count <= 512,
          bytes.allSatisfy({ byte in
            byte == 0x20 || (0x41...0x5a).contains(byte) || (0x61...0x7a).contains(byte)
          }),
          let value = String(data: bytes, encoding: .ascii)
    else { throw IOSBridgeFailure(.invalidRequest) }
    let words = value.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    guard words.count == expectedWords,
          words.allSatisfy({ !$0.isEmpty && $0.count <= 16 })
    else { throw IOSBridgeFailure(.invalidRequest) }
    return words
  }

  private func guardedSession(_ operation: () throws -> VaultSessionReply) -> VaultSessionReply {
    do { return try operation() }
    catch let failure as IOSBridgeFailure { return VaultSessionReply(error: failure.code) }
    catch { return VaultSessionReply(error: .internalFailure) }
  }

  private func guardedPayload(_ operation: () throws -> PayloadReply) -> PayloadReply {
    do { return try operation() }
    catch let failure as IOSBridgeFailure { return PayloadReply(error: failure.code) }
    catch { return PayloadReply(error: .internalFailure) }
  }
}

private enum IOSSessionOrigin { case master, recovery, biometric }

private struct IOSVaultSession {
  let vaultId: String
  var keyGeneration: Data
  var dek: Data
  let origin: IOSSessionOrigin
  let credentialVerifiedAtUptime: TimeInterval

  mutating func destroy() {
    keyGeneration.resetBytes(in: 0..<keyGeneration.count)
    dek.resetBytes(in: 0..<dek.count)
  }
}

private struct IOSParsedMasterEnvelope {
  let salt: Data
  let keyGeneration: Data
  let nonce: Data
  let wrappedDek: Data
}

private struct IOSParsedRecoveryEnvelope {
  let keyGeneration: Data
  let nonce: Data
  let wrappedDek: Data
}

private struct IOSRecoveryCeremony {
  let words: [String]
  var entropy: Data
  var envelope: Data
  let positions: [Int]

  mutating func destroy() {
    entropy.resetBytes(in: 0..<entropy.count)
    envelope.resetBytes(in: 0..<envelope.count)
  }
}

struct IOSBiometricMaterial {
  let vaultId: String
  var keyGeneration: Data
  var dek: Data

  mutating func destroy() {
    keyGeneration.resetBytes(in: 0..<keyGeneration.count)
    dek.resetBytes(in: 0..<dek.count)
  }
}

private final class IOSBridgeFailure: Error {
  let code: KeyBridgeErrorCode
  init(_ code: KeyBridgeErrorCode) { self.code = code }
}

private final class IOSDurableNonceAllocator {
  private let lock = NSLock()
  private let service = "dev.localhold.vault.nonce.v1"

  func initialize(keyGeneration: Data) throws {
    lock.lock()
    defer { lock.unlock() }
    guard try read(keyGeneration: keyGeneration) == nil else {
      throw IOSBridgeFailure(.integrityFailure)
    }
    var state = Data()
    state.append(try secureRandom(count: 4))
    state.appendBigEndian(UInt64(0))
    let status = SecItemAdd(baseQuery(keyGeneration: keyGeneration).merging([
      kSecValueData as String: state,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]) { _, new in new } as CFDictionary, nil)
    guard status == errSecSuccess else { throw IOSBridgeFailure(.internalFailure) }
  }

  func requirePresent(keyGeneration: Data) throws {
    lock.lock()
    defer { lock.unlock() }
    guard try read(keyGeneration: keyGeneration) != nil else {
      throw IOSBridgeFailure(.integrityFailure)
    }
  }

  func reserve(keyGeneration: Data) throws -> Data {
    lock.lock()
    defer { lock.unlock() }
    guard let state = try read(keyGeneration: keyGeneration), state.count == nonceBytes else {
      throw IOSBridgeFailure(.integrityFailure)
    }
    var cursor = DataCursor(state)
    let epoch = try cursor.read(count: 4)
    let counter = try cursor.readUInt64()
    guard counter < UInt64.max else { throw IOSBridgeFailure(.integrityFailure) }
    var updated = Data(epoch)
    updated.appendBigEndian(counter + 1)
    let status = SecItemUpdate(
      baseQuery(keyGeneration: keyGeneration) as CFDictionary,
      [kSecValueData as String: updated] as CFDictionary
    )
    guard status == errSecSuccess else { throw IOSBridgeFailure(.internalFailure) }
    var nonce = Data(epoch)
    nonce.appendBigEndian(counter)
    return nonce
  }

  private func read(keyGeneration: Data) throws -> Data? {
    var query = baseQuery(keyGeneration: keyGeneration)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw IOSBridgeFailure(.internalFailure)
    }
    return data
  }

  private func baseQuery(keyGeneration: Data) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: keyGeneration.base64URL,
      kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
    ]
  }
}

private final class IOSMasterCredentialFreshnessStore {
  private let lock = NSLock()
  private let service = "dev.localhold.master-freshness.v1"

  func record(vaultId: String) throws {
    lock.lock()
    defer { lock.unlock() }
    var timestamp = UInt64(Date().timeIntervalSince1970).bigEndian
    let value = Swift.withUnsafeBytes(of: &timestamp) { Data($0) }
    let query = baseQuery(vaultId: vaultId)
    let updateStatus = SecItemUpdate(
      query as CFDictionary,
      [kSecValueData as String: value] as CFDictionary
    )
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw IOSBridgeFailure(.internalFailure)
    }
    let addStatus = SecItemAdd(query.merging([
      kSecValueData as String: value,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]) { _, new in new } as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw IOSBridgeFailure(.internalFailure)
    }
  }

  func isFresh(vaultId: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    var query = baseQuery(vaultId: vaultId)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let value = result as? Data,
          value.count == MemoryLayout<UInt64>.size
    else { return false }
    let verifiedAt = value.withUnsafeBytes {
      $0.loadUnaligned(as: UInt64.self).bigEndian
    }
    let now = UInt64(Date().timeIntervalSince1970)
    return now >= verifiedAt && now - verifiedAt <= masterFreshnessSeconds
  }

  private func baseQuery(vaultId: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: vaultId,
      kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
    ]
  }
}

private struct DataCursor {
  private let data: Data
  private var offset = 0

  init(_ data: Data) { self.data = data }

  mutating func readUInt8() throws -> UInt8 {
    let value = try read(count: 1)
    return value[value.startIndex]
  }

  mutating func readUInt32() throws -> UInt32 {
    try readInteger(UInt32.self)
  }

  mutating func readUInt64() throws -> UInt64 {
    try readInteger(UInt64.self)
  }

  mutating func read(count: Int) throws -> Data {
    guard count >= 0, offset + count <= data.count else {
      throw IOSBridgeFailure(.invalidRequest)
    }
    defer { offset += count }
    return data.subdata(in: offset..<(offset + count))
  }

  mutating func readRemaining(minimum: Int = 0, exact: Int? = nil) throws -> Data {
    let remaining = data.count - offset
    guard remaining >= minimum, exact == nil || remaining == exact else {
      throw IOSBridgeFailure(.invalidRequest)
    }
    return try read(count: remaining)
  }

  private mutating func readInteger<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
    let bytes = try read(count: MemoryLayout<T>.size)
    return bytes.withUnsafeBytes { $0.loadUnaligned(as: T.self).bigEndian }
  }
}

private func secureRandom(count: Int) throws -> Data {
  var data = Data(count: count)
  let status = data.withUnsafeMutableBytes { buffer in
    SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
  }
  guard status == errSecSuccess else { throw IOSBridgeFailure(.platformUnavailable) }
  return data
}

private func sealAesGcm(key: Data, nonce: Data, plaintext: Data, aad: Data) throws -> Data {
  let sealed = try AES.GCM.seal(
    plaintext,
    using: SymmetricKey(data: key),
    nonce: try AES.GCM.Nonce(data: nonce),
    authenticating: aad
  )
  return sealed.ciphertext + sealed.tag
}

private func openAesGcm(
  key: Data,
  nonce: Data,
  ciphertextAndTag: Data,
  aad: Data
) throws -> Data {
  guard ciphertextAndTag.count >= 16 else { throw IOSBridgeFailure(.integrityFailure) }
  let split = ciphertextAndTag.count - 16
  let box = try AES.GCM.SealedBox(
    nonce: try AES.GCM.Nonce(data: nonce),
    ciphertext: ciphertextAndTag.prefix(split),
    tag: ciphertextAndTag.suffix(16)
  )
  return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
}

private extension Data {
  var base64URL: String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
    var bigEndian = value.bigEndian
    Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
  }
}

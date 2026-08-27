// SPDX-License-Identifier: MPL-2.0

import Foundation
import LocalAuthentication
import Security

final class IOSBiometricCoordinator {
  private let service: IOSVaultCryptoService
  private let envelopeService = "dev.localhold.biometric-envelope.v1"

  init(service: IOSVaultCryptoService) {
    self.service = service
  }

  func enable(_ sessionHandle: String) async -> StatusReply {
    if let error = service.sensitiveSessionError(sessionHandle) {
      return StatusReply(error: error)
    }
    guard var material = service.biometricMaterial(sessionHandle) else {
      return StatusReply(error: .sessionNotFound)
    }
    defer { material.destroy() }
    let wrapper = IOSBiometricWrapper(alias: material.vaultId)
    do {
      try wrapper.enableAfterMasterConfirmation(
        masterUnlockSucceeded: true,
        userConfirmed: true
      )
      let wrapped = try wrapper.wrap(
        material.dek,
        aad: aad(vaultId: material.vaultId, keyGeneration: material.keyGeneration),
        reason: "Enable biometric unlock"
      )
      var envelope = Data()
      appendBigEndian(UInt32(0x4c484231), to: &envelope)
      envelope.append(UInt8(1))
      envelope.append(material.keyGeneration)
      envelope.append(wrapped.nonce)
      envelope.append(wrapped.ciphertext)
      envelope.append(wrapped.tag)
      try store(envelope, vaultId: material.vaultId)
      envelope.resetBytes(in: 0..<envelope.count)
      return StatusReply()
    } catch let failure as IOSBiometricWrapper.WrapperError {
      return StatusReply(error: map(failure))
    } catch {
      return StatusReply(error: .biometricUnavailable)
    }
  }

  func open(_ vaultId: String) async -> VaultSessionReply {
    guard vaultId.range(
      of: "^[A-Za-z0-9_-]{22}$",
      options: .regularExpression
    ) != nil else { return VaultSessionReply(error: .invalidRequest) }
    guard service.isMasterCredentialFresh(vaultId) else {
      return VaultSessionReply(error: .reauthenticationRequired)
    }
    do {
      guard let envelope = try read(vaultId: vaultId), envelope.count == 81 else {
        return VaultSessionReply(error: .biometricUnavailable)
      }
      let magic = envelope.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
      guard magic == 0x4c484231, envelope[4] == 1 else {
        return VaultSessionReply(error: .unsupportedVersion)
      }
      var keyGeneration = Data(envelope[5..<21])
      let nonce = Data(envelope[21..<33])
      let ciphertext = Data(envelope[33..<65])
      let tag = Data(envelope[65..<81])
      defer { keyGeneration.resetBytes(in: 0..<keyGeneration.count) }
      let wrapper = IOSBiometricWrapper(alias: vaultId)
      var dek = try wrapper.unwrap(
        .init(nonce: nonce, ciphertext: ciphertext, tag: tag),
        aad: aad(vaultId: vaultId, keyGeneration: keyGeneration),
        reason: "Unlock Localhold"
      )
      defer { dek.resetBytes(in: 0..<dek.count) }
      return service.openBiometric(
        vaultId: vaultId,
        keyGeneration: keyGeneration,
        dek: dek
      )
    } catch let failure as IOSBiometricWrapper.WrapperError {
      return VaultSessionReply(error: map(failure))
    } catch {
      return VaultSessionReply(error: .biometricUnavailable)
    }
  }

  func disable(_ sessionHandle: String) async -> StatusReply {
    if let error = service.sensitiveSessionError(sessionHandle) {
      return StatusReply(error: error)
    }
    guard var material = service.biometricMaterial(sessionHandle) else {
      return StatusReply(error: .sessionNotFound)
    }
    defer { material.destroy() }
    do {
      try IOSBiometricWrapper(alias: material.vaultId)
        .deleteAfterMasterConfirmation(true)
      try deleteEnvelope(vaultId: material.vaultId)
      return StatusReply()
    } catch let failure as IOSBiometricWrapper.WrapperError {
      return StatusReply(error: map(failure))
    } catch {
      return StatusReply(error: .platformUnavailable)
    }
  }

  func status(_ vaultId: String) -> BiometricStatusReply {
    guard vaultId.range(of: "^[A-Za-z0-9_-]{22}$", options: .regularExpression) != nil else {
      return BiometricStatusReply(configured: false, error: .invalidRequest)
    }
    let context = LAContext()
    var evaluationError: NSError?
    let available = context.canEvaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      error: &evaluationError
    )
    do {
      let configured = try read(vaultId: vaultId) != nil
      return BiometricStatusReply(
        configured: configured && available,
        invalidated: configured && !available
      )
    } catch {
      return BiometricStatusReply(configured: false, error: .platformUnavailable)
    }
  }

  private func aad(vaultId: String, keyGeneration: Data) -> Data {
    Data("localhold.biometric-wrapper.v1|\(vaultId)|\(keyGeneration.base64URL)".utf8)
  }

  private func store(_ value: Data, vaultId: String) throws {
    try deleteEnvelope(vaultId: vaultId)
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: envelopeService,
      kSecAttrAccount: vaultId,
      kSecAttrSynchronizable: false,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData: value,
    ]
    guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
      throw IOSBiometricStorageFailure()
    }
  }

  private func read(vaultId: String) throws -> Data? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: envelopeService,
      kSecAttrAccount: vaultId,
      kSecAttrSynchronizable: false,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let value = result as? Data else {
      throw IOSBiometricStorageFailure()
    }
    return value
  }

  private func deleteEnvelope(vaultId: String) throws {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: envelopeService,
      kSecAttrAccount: vaultId,
      kSecAttrSynchronizable: false,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw IOSBiometricStorageFailure()
    }
  }

  private func map(_ failure: IOSBiometricWrapper.WrapperError) -> KeyBridgeErrorCode {
    switch failure {
    case .invalidEnvelope:
      return .biometricInvalidated
    case .authenticationFailed:
      return .invalidCredentials
    case .platformUnavailable:
      return .biometricUnavailable
    case .masterConfirmationRequired:
      return .invalidRequest
    }
  }

  private func appendBigEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var bigEndian = value.bigEndian
    Swift.withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
  }
}

private struct IOSBiometricStorageFailure: Error {}

private extension Data {
  var base64URL: String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Production device-only biometric wrapper. Key bytes may exist briefly in native
/// memory but are never returned through the Flutter bridge.
final class IOSBiometricWrapper {
    struct WrappedValue {
        let nonce: Data
        let ciphertext: Data
        let tag: Data
    }

    enum WrapperError: Error {
        case platformUnavailable
        case invalidEnvelope
        case authenticationFailed
        case masterConfirmationRequired
    }

    private let service = "dev.localhold.biometric-wrapper"
    private let account: String

    init(alias: String) {
        account = alias
    }

    func enableAfterMasterConfirmation(
        masterUnlockSucceeded: Bool,
        userConfirmed: Bool
    ) throws {
        guard masterUnlockSucceeded, userConfirmed else {
            throw WrapperError.masterConfirmationRequired
        }
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw WrapperError.platformUnavailable
        }
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &accessError
        ) else {
            throw WrapperError.platformUnavailable
        }
        var key = Data(count: 32)
        let randomStatus = key.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw WrapperError.platformUnavailable
        }
        defer { key.resetBytes(in: 0..<key.count) }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessControl: access,
            kSecAttrSynchronizable: false,
            kSecValueData: key,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WrapperError.platformUnavailable
        }
    }

    func wrap(_ value: Data, aad: Data, reason: String) throws -> WrappedValue {
        var keyData = try readKey(reason: reason)
        defer { keyData.resetBytes(in: 0..<keyData.count) }
        let sealed = try AES.GCM.seal(
            value,
            using: SymmetricKey(data: keyData),
            authenticating: aad
        )
        return WrappedValue(
            nonce: Data(sealed.nonce),
            ciphertext: sealed.ciphertext,
            tag: sealed.tag
        )
    }

    func unwrap(_ value: WrappedValue, aad: Data, reason: String) throws -> Data {
        var keyData = try readKey(reason: reason)
        defer { keyData.resetBytes(in: 0..<keyData.count) }
        guard value.nonce.count == 12, value.tag.count == 16 else {
            throw WrapperError.invalidEnvelope
        }
        let box = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: value.nonce),
            ciphertext: value.ciphertext,
            tag: value.tag
        )
        return try AES.GCM.open(
            box,
            using: SymmetricKey(data: keyData),
            authenticating: aad
        )
    }

    func deleteAfterMasterConfirmation(_ confirmed: Bool) throws {
        guard confirmed else { throw WrapperError.masterConfirmationRequired }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WrapperError.platformUnavailable
        }
    }

    private func readKey(reason: String) throws -> Data {
        let context = LAContext()
        context.localizedFallbackTitle = "Use master password"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
            kSecUseOperationPrompt: reason,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, data.count == 32 else {
                throw WrapperError.invalidEnvelope
            }
            return data
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
            throw WrapperError.authenticationFailed
        case errSecItemNotFound:
            throw WrapperError.platformUnavailable
        default:
            throw WrapperError.platformUnavailable
        }
    }
}

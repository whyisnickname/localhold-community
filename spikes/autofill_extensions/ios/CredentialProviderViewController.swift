// SPDX-License-Identifier: MPL-2.0
import AuthenticationServices
import Foundation

/// Boundary prototype. The production extension receives only exactly matched
/// record identifiers and must unlock before reading credential material.
final class CredentialProviderViewController: ASCredentialProviderViewController {
    override func prepareCredentialList(
        for serviceIdentifiers: [ASCredentialServiceIdentifier]
    ) {
        let origins = serviceIdentifiers.compactMap(VerifiedServiceOrigin.init)
        guard !origins.isEmpty else {
            extensionContext.cancelRequest(
                withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue
                )
            )
            return
        }
        // UI selection and vault unlock are intentionally outside this boundary spike.
    }

    override func provideCredentialWithoutUserInteraction(
        for credentialIdentity: ASPasswordCredentialIdentity
    ) {
        // Never return a secret while the vault is locked.
        extensionContext.cancelRequest(
            withError: NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.userInteractionRequired.rawValue
            )
        )
    }
}

struct VerifiedServiceOrigin: Equatable {
    let origin: IOSNativeCredentialOrigin

    init?(_ identifier: ASCredentialServiceIdentifier) {
        guard !identifier.identifier.isEmpty,
              identifier.identifier.unicodeScalars.allSatisfy(\.isASCII)
        else {
            return nil
        }
        switch identifier.type {
        case .domain:
            guard let host = IOSStrictOriginMatcher.canonicalWebHost(identifier.identifier) else {
                return nil
            }
            origin = .web(host: host, port: 443)
        case .URL:
            guard let components = URLComponents(string: identifier.identifier),
                  components.scheme?.lowercased() == "https",
                  components.user == nil,
                  components.password == nil,
                  let rawHost = components.host,
                  let host = IOSStrictOriginMatcher.canonicalWebHost(rawHost)
            else {
                return nil
            }
            let port = components.port ?? 443
            guard (1...65_535).contains(port) else { return nil }
            origin = .web(host: host, port: port)
        @unknown default:
            return nil
        }
    }
}

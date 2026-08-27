// SPDX-License-Identifier: MPL-2.0
import Foundation

enum IOSNativeCredentialOrigin: Equatable {
    case app(bundleID: String, teamID: String)
    case web(host: String, port: Int)
}

enum IOSStrictOriginMatcher {
    static func matches(
        saved: IOSNativeCredentialOrigin,
        requested: IOSNativeCredentialOrigin
    ) -> Bool {
        switch (saved, requested) {
        case let (.app(savedBundle, savedTeam), .app(requestedBundle, requestedTeam)):
            return !savedBundle.isEmpty &&
                !savedTeam.isEmpty &&
                savedBundle == requestedBundle &&
                savedTeam == requestedTeam
        case let (.web(savedHost, savedPort), .web(requestedHost, requestedPort)):
            guard let canonicalSaved = canonicalWebHost(savedHost),
                  let canonicalRequested = canonicalWebHost(requestedHost),
                  (1...65_535).contains(savedPort),
                  (1...65_535).contains(requestedPort)
            else {
                return false
            }
            return canonicalSaved == canonicalRequested && savedPort == requestedPort
        default:
            return false
        }
    }

    static func canonicalWebHost(_ raw: String) -> String? {
        guard raw == raw.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.utf8.count <= 253,
              raw.unicodeScalars.allSatisfy(\.isASCII)
        else {
            return nil
        }
        let host = raw.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard host.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.allSatisfy({ label in
            !label.isEmpty &&
                label.utf8.count <= 63 &&
                label.first != "-" &&
                label.last != "-"
        }) else {
            return nil
        }
        return host
    }
}

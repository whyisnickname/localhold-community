// SPDX-License-Identifier: MPL-2.0
import Foundation

let savedApp = IOSNativeCredentialOrigin.app(bundleID: "com.example.bank", teamID: "TEAM123456")
precondition(IOSStrictOriginMatcher.matches(saved: savedApp, requested: savedApp))
precondition(!IOSStrictOriginMatcher.matches(
    saved: savedApp,
    requested: .app(bundleID: "com.example.bank", teamID: "ATTACKER00")
))
precondition(!IOSStrictOriginMatcher.matches(
    saved: savedApp,
    requested: .app(bundleID: "com.example.bank.fake", teamID: "TEAM123456")
))

let savedWeb = IOSNativeCredentialOrigin.web(host: "login.example.com", port: 443)
precondition(IOSStrictOriginMatcher.matches(
    saved: savedWeb,
    requested: .web(host: "LOGIN.EXAMPLE.COM", port: 443)
))
for origin in [
    IOSNativeCredentialOrigin.web(host: "evil.example.com", port: 443),
    IOSNativeCredentialOrigin.web(host: "login.example.com.evil.test", port: 443),
    IOSNativeCredentialOrigin.web(host: "login.example.com", port: 8443),
    IOSNativeCredentialOrigin.web(host: "exаmple.com", port: 443),
    IOSNativeCredentialOrigin.web(host: ".example.com", port: 443),
    IOSNativeCredentialOrigin.web(host: "example..com", port: 443),
] {
    precondition(!IOSStrictOriginMatcher.matches(saved: savedWeb, requested: origin))
}

print("Swift exact app/web origin fixtures passed")

// SPDX-License-Identifier: MPL-2.0

import Flutter
import Foundation

private let LOCALHOLD_STAGE2_SPIKE_DO_NOT_SHIP = true

/// Fail-closed Stage 2 adapter with no cryptography or key state.
public final class LocalholdKeyBridgePlugin: NSObject, FlutterPlugin, KeyBridgeHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    precondition(LOCALHOLD_STAGE2_SPIKE_DO_NOT_SHIP)
    let instance = LocalholdKeyBridgePlugin()
    KeyBridgeHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  func createVaultKey(request: CreateVaultKeyRequest) throws -> VaultSessionReply {
    VaultSessionReply(error: .notImplemented)
  }

  func openVaultSession(request: OpenVaultSessionRequest) throws -> VaultSessionReply {
    VaultSessionReply(error: .notImplemented)
  }

  func encryptPayload(request: EncryptPayloadRequest) throws -> PayloadReply {
    PayloadReply(error: .notImplemented)
  }

  func decryptPayload(request: DecryptPayloadRequest) throws -> PayloadReply {
    PayloadReply(error: .notImplemented)
  }

  func rewrapVaultKey(request: RewrapVaultKeyRequest) throws -> PayloadReply {
    PayloadReply(error: .notImplemented)
  }

  func closeSession(sessionHandle: String) throws -> StatusReply {
    StatusReply(error: .notImplemented)
  }

  func closeAllSessions() throws -> StatusReply {
    StatusReply(error: .notImplemented)
  }
}

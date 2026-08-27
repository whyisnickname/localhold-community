// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

public final class LocalholdKeyBridgePlugin: NSObject, FlutterPlugin, KeyBridgeHostApi {
  private let service = IOSVaultCryptoService()
  private lazy var biometricCoordinator = IOSBiometricCoordinator(service: service)
  private weak var recoveryAlert: UIAlertController?
  private var observerTokens: [NSObjectProtocol] = []
  private var privacyEnabled = false
  private var lifecycleCoverRequired = false
  private var privacyCover: UIView?
  private var clipboardDigest: Data?
  private var clipboardChangeCount: Int?
  private var backgroundedAtUptime: TimeInterval?
  private var backgroundLockWorkItem: DispatchWorkItem?

  override init() {
    super.init()
    observerTokens.append(NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        if UIScreen.main.isCaptured {
          self?.recoveryAlert?.dismiss(animated: false)
        }
        self?.updatePrivacyCover()
      }
    })
    observerTokens.append(NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.lifecycleCoverRequired = true
        self.backgroundedAtUptime = ProcessInfo.processInfo.systemUptime
        self.backgroundLockWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
          _ = self?.service.closeAll()
        }
        self.backgroundLockWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
        self.updatePrivacyCover()
      }
    })
    observerTokens.append(NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        if let backgroundedAt = self.backgroundedAtUptime {
          let elapsed = ProcessInfo.processInfo.systemUptime - backgroundedAt
          if elapsed < 0 || elapsed >= 30 {
            _ = self.service.closeAll()
          }
        }
        self.backgroundedAtUptime = nil
        self.backgroundLockWorkItem?.cancel()
        self.backgroundLockWorkItem = nil
        self.lifecycleCoverRequired = false
        self.updatePrivacyCover()
      }
    })
    observerTokens.append(NotificationCenter.default.addObserver(
      forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      _ = self?.service.closeAll()
    })
    observerTokens.append(NotificationCenter.default.addObserver(
      forName: UIApplication.willTerminateNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      _ = self?.service.closeAll()
    })
  }

  deinit {
    backgroundLockWorkItem?.cancel()
    _ = service.closeAll()
    observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LocalholdKeyBridgePlugin()
    KeyBridgeHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  func createVaultKey(request: CreateVaultKeyRequest) throws -> VaultSessionReply {
    service.create(request)
  }

  func openVaultSession(request: OpenVaultSessionRequest) throws -> VaultSessionReply {
    service.open(request)
  }

  func encryptPayload(request: EncryptPayloadRequest) throws -> PayloadReply {
    service.encrypt(request)
  }

  func decryptPayload(request: DecryptPayloadRequest) throws -> PayloadReply {
    service.decrypt(request)
  }

  func rewrapVaultKey(request: RewrapVaultKeyRequest) throws -> PayloadReply {
    service.rewrap(request)
  }

  func beginRecoveryKey(sessionHandle: String) throws -> RecoveryCeremonyReply {
    service.beginRecovery(sessionHandle)
  }

  func presentRecoveryKey(ceremonyHandle: String) throws -> StatusReply {
    MainActor.assumeIsolated {
      guard !UIScreen.main.isCaptured else { return StatusReply(error: .sessionLocked) }
      guard let words = service.recoveryWordsForPresentation(ceremonyHandle) else {
        return StatusReply(error: .invalidRequest)
      }
      guard let presenter = Self.topViewController() else {
        return StatusReply(error: .platformUnavailable)
      }
      let text = words.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
      let alert = UIAlertController(
        title: "Localhold recovery key",
        message: text,
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Done", style: .default))
      recoveryAlert = alert
      presenter.present(alert, animated: true)
      return StatusReply()
    }
  }

  func confirmRecoveryKey(request: ConfirmRecoveryKeyRequest) throws -> PayloadReply {
    service.confirmRecovery(request)
  }

  func openVaultWithRecovery(request: OpenVaultWithRecoveryRequest) throws -> VaultSessionReply {
    service.openRecovery(request)
  }

  func cancelRecoveryKey(ceremonyHandle: String) throws -> StatusReply {
    MainActor.assumeIsolated {
      recoveryAlert?.dismiss(animated: false)
      return service.cancelRecovery(ceremonyHandle)
    }
  }

  func setVaultPrivacyActive(active: Bool) throws -> StatusReply {
    MainActor.assumeIsolated {
      privacyEnabled = active
      updatePrivacyCover()
      return StatusReply()
    }
  }

  func copySensitiveClipboard(request: SensitiveClipboardRequest) throws -> StatusReply {
    MainActor.assumeIsolated {
      var bytes = request.utf8Value.data
      defer { bytes.resetBytes(in: 0..<bytes.count) }
      guard !bytes.isEmpty,
            bytes.count <= 2 * 1024 * 1024,
            [15, 30, 60, 120].contains(request.expirySeconds),
            let value = String(data: bytes, encoding: .utf8)
      else { return StatusReply(error: .invalidRequest) }
      let pasteboard = UIPasteboard.general
      pasteboard.setItems(
        [[UTType.utf8PlainText.identifier: value]],
        options: [
          .localOnly: true,
          .expirationDate: Date(timeIntervalSinceNow: TimeInterval(request.expirySeconds)),
        ]
      )
      clipboardDigest = Data(SHA256.hash(data: Data(value.utf8)))
      clipboardChangeCount = pasteboard.changeCount
      let generation = pasteboard.changeCount
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(request.expirySeconds))) {
        [weak self] in
        MainActor.assumeIsolated {
          if self?.clipboardChangeCount == generation {
            _ = try? self?.clearSensitiveClipboard()
          }
        }
      }
      return StatusReply()
    }
  }

  func clearSensitiveClipboard() throws -> StatusReply {
    MainActor.assumeIsolated {
      let pasteboard = UIPasteboard.general
      guard let expected = clipboardDigest,
            let expectedChange = clipboardChangeCount
      else { return StatusReply() }
      if pasteboard.changeCount == expectedChange,
         let current = pasteboard.string,
         Data(SHA256.hash(data: Data(current.utf8))) == expected {
        pasteboard.items = []
      }
      clipboardDigest = nil
      clipboardChangeCount = nil
      return StatusReply()
    }
  }

  func enableBiometric(sessionHandle: String) async throws -> StatusReply {
    await biometricCoordinator.enable(sessionHandle)
  }

  func openVaultWithBiometric(vaultId: String) async throws -> VaultSessionReply {
    await biometricCoordinator.open(vaultId)
  }

  func disableBiometric(sessionHandle: String) async throws -> StatusReply {
    await biometricCoordinator.disable(sessionHandle)
  }

  func biometricStatus(vaultId: String) throws -> BiometricStatusReply {
    biometricCoordinator.status(vaultId)
  }

  func excludePathFromBackup(absolutePath: String) throws -> StatusReply {
    let candidate = URL(fileURLWithPath: absolutePath).standardizedFileURL
    let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path
    guard candidate.path.hasPrefix(home + "/") else {
      return StatusReply(error: .invalidRequest)
    }
    do {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var mutable = candidate
      try mutable.setResourceValues(values)
      return StatusReply()
    } catch {
      return StatusReply(error: .platformUnavailable)
    }
  }

  func closeSession(sessionHandle: String) throws -> StatusReply {
    service.close(sessionHandle)
  }

  func closeAllSessions() throws -> StatusReply {
    service.closeAll()
  }

  @MainActor
  private static func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    var current = root
    while let presented = current?.presentedViewController { current = presented }
    return current
  }

  @MainActor
  private func updatePrivacyCover() {
    let shouldCover = privacyEnabled && (lifecycleCoverRequired || UIScreen.main.isCaptured)
    guard shouldCover else {
      privacyCover?.removeFromSuperview()
      privacyCover = nil
      return
    }
    guard privacyCover == nil,
          let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = .black
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(cover)
    privacyCover = cover
  }
}

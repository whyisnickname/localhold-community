// SPDX-License-Identifier: MPL-2.0

import Foundation
import Security

public enum IOSInboundShareInputKind: Int {
  case text = 0
  case url = 1
  case file = 2
  case image = 3
}

/// Share extensions call this streaming stager before launching Localhold.
/// It writes only to the configured app-group container and never uses a network API.
public final class IOSInboundShareStager {
  private static let inlineMaximum = 64 * 1024
  private static let fileMaximum = 256 * 1024 * 1024
  private static let queueMaximum = 8
  private static let queueByteMaximum = 512 * 1024 * 1024
  private static let lifetimeMilliseconds: Int64 = 24 * 60 * 60 * 1000

  public static func stageData(_ data: Data, kind: IOSInboundShareInputKind) -> Bool {
    let maximum = (kind == .text || kind == .url) ? inlineMaximum : fileMaximum
    guard !data.isEmpty, data.count <= maximum else { return false }
    return stage(kind: kind, declaredLength: data.count) { output in
      try output.write(contentsOf: data)
    }
  }

  public static func stageFile(at inputURL: URL, kind: IOSInboundShareInputKind) -> Bool {
    guard kind == .file || kind == .image,
          let input = try? FileHandle(forReadingFrom: inputURL),
          let size = try? input.seekToEnd(), size > 0, size <= UInt64(fileMaximum)
    else { return false }
    defer { try? input.close() }
    do { try input.seek(toOffset: 0) } catch { return false }
    return stage(kind: kind, declaredLength: Int(size)) { output in
      while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
        try output.write(contentsOf: chunk)
      }
    }
  }

  private static func stage(
    kind: IOSInboundShareInputKind,
    declaredLength: Int,
    writer: (FileHandle) throws -> Void
  ) -> Bool {
    guard let directory = IOSInboundShareLocation.directory(), let id = randomId() else {
      return false
    }
    let pending = ((try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.fileSizeKey]
    )) ?? []).filter { $0.pathExtension == "payload" }
    let pendingBytes = pending.reduce(0) { total, url in
      total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
    guard pending.count < queueMaximum,
          pendingBytes <= queueByteMaximum - declaredLength
    else { return false }
    let payload = directory.appendingPathComponent("\(id).payload")
    let metadata = directory.appendingPathComponent("\(id).json")
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      guard FileManager.default.createFile(
        atPath: payload.path,
        contents: nil,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
      ) else { return false }
      let output = try FileHandle(forWritingTo: payload)
      do {
        try writer(output)
        try output.synchronize()
        try output.close()
      } catch {
        try? output.close()
        throw error
      }
      let actual = try payload.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
      guard actual == declaredLength else { throw CocoaError(.fileReadCorruptFile) }
      let now = Int64(Date().timeIntervalSince1970 * 1000)
      let value: [String: Any] = [
        "id": id,
        "kind": kind.rawValue,
        "bytes": actual,
        "received": now,
        "expires": now + lifetimeMilliseconds,
      ]
      let bytes = try JSONSerialization.data(withJSONObject: value)
      try bytes.write(
        to: metadata,
        options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
      )
      return true
    } catch {
      try? FileManager.default.removeItem(at: payload)
      try? FileManager.default.removeItem(at: metadata)
      return false
    }
  }

  private static func randomId() -> String? {
    var bytes = [UInt8](repeating: 0, count: 16)
    let status = bytes.withUnsafeMutableBytes { buffer in
      guard let baseAddress = buffer.baseAddress else { return errSecParam }
      return SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
    }
    guard status == errSecSuccess else { return nil }
    return Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

enum IOSInboundShareLocation {
  static func directory() -> URL? {
    let manager = FileManager.default
    let configuredGroup = Bundle.main.object(
      forInfoDictionaryKey: "LocalholdAppGroupIdentifier"
    ) as? String
    let root: URL?
    if let configuredGroup, !configuredGroup.isEmpty {
      root = manager.containerURL(forSecurityApplicationGroupIdentifier: configuredGroup)
      guard root != nil else { return nil }
    } else {
      root = manager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    }
    return root?.appendingPathComponent("localhold_inbound_share_v1", isDirectory: true)
  }
}

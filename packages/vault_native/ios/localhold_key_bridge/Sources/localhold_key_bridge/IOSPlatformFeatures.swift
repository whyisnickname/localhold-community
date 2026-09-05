// SPDX-License-Identifier: MPL-2.0

import Foundation
import Flutter
import Security
import UIKit
import UserNotifications

public enum IOSInboundShareInputKind: Int {
  case text = 0
  case url = 1
  case file = 2
  case image = 3
}

/// Share extensions call this streaming stager before launching Localhold.
/// It writes only to the app-group container and never invokes a network API.
public final class IOSInboundShareStager {
  private static let inlineMaximum = 64 * 1024
  private static let fileMaximum = 256 * 1024 * 1024
  private static let lifetimeMilliseconds: Int64 = 24 * 60 * 60 * 1000

  public static func stageData(_ data: Data, kind: IOSInboundShareInputKind) -> Bool {
    let maximum = (kind == .text || kind == .url) ? inlineMaximum : fileMaximum
    guard !data.isEmpty, data.count <= maximum else { return false }
    return stage(kind: kind, declaredLength: data.count) { output in
      try output.write(contentsOf: data)
    }
  }

  public static func stageFile(
    at inputURL: URL,
    kind: IOSInboundShareInputKind
  ) -> Bool {
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
    guard let directory = IOSInboundShareLocation.directory() else { return false }
    guard let id = randomId() else { return false }
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
      try bytes.write(to: metadata, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
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
    guard status == errSecSuccess else {
      return nil
    }
    return Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

private enum IOSInboundShareLocation {
  static func directory() -> URL? {
    let manager = FileManager.default
    let configuredGroup = Bundle.main.object(
      forInfoDictionaryKey: "LocalholdAppGroupIdentifier"
    ) as? String
    let shared = configuredGroup.flatMap {
      manager.containerURL(forSecurityApplicationGroupIdentifier: $0)
    }
    let root = shared ?? manager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first
    return root?.appendingPathComponent("localhold_inbound_share_v1", isDirectory: true)
  }
}

final class IOSPlatformFeatures: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
  private let center = UNUserNotificationCenter.current()
  private let store = IOSInboundShareStore()
  private let actionLock = NSLock()
  private var pendingLauncherAction: Int64 = 0

  override init() {
    super.init()
    let snooze = UNNotificationAction(
      identifier: Self.snoozeAction,
      title: Locale.current.languageCode == "ru" ? "Отложить" : "Snooze"
    )
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: Self.reminderCategory,
        actions: [snooze],
        intentIdentifiers: []
      )
    ])
    center.delegate = self
  }

  func notificationPermissionStatus() async -> NotificationPermissionReply {
    let settings = await center.notificationSettings()
    let state: NotificationPermissionCode = switch settings.authorizationStatus {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized, .provisional, .ephemeral: .authorized
    @unknown default: .restricted
    }
    return NotificationPermissionReply(state: state)
  }

  func requestNotificationPermission() async -> NotificationPermissionReply {
    do {
      _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
      return await notificationPermissionStatus()
    } catch {
      return NotificationPermissionReply(state: .denied, error: .permissionDenied)
    }
  }

  func openNotificationSettings() -> FeatureStatusReply {
    MainActor.assumeIsolated {
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        return FeatureStatusReply(error: .platformUnavailable)
      }
      UIApplication.shared.open(url)
      return FeatureStatusReply()
    }
  }

  func resolveWallClock(_ request: WallClockRequest) -> WallClockReply {
    guard request.timeZoneId.count <= 128,
          let zone = TimeZone(identifier: request.timeZoneId)
    else { return invalidWallClock() }
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = zone
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = zone
    components.year = Int(request.year)
    components.month = Int(request.month)
    components.day = Int(request.day)
    components.hour = Int(request.hour)
    components.minute = Int(request.minute)
    components.second = 0
    guard let resolved = calendar.date(from: components) else { return invalidWallClock() }
    let wanted = [Int(request.year), Int(request.month), Int(request.day), Int(request.hour), Int(request.minute)]
    func wall(_ date: Date) -> [Int] {
      let value = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
      return [value.year, value.month, value.day, value.hour, value.minute].map { $0 ?? -1 }
    }
    let resolution: WallClockResolutionCode
    if wall(resolved) != wanted {
      resolution = .gapAdjusted
    } else if wall(resolved.addingTimeInterval(3600)) == wanted {
      resolution = .earlier
    } else if wall(resolved.addingTimeInterval(-3600)) == wanted {
      resolution = .later
    } else {
      resolution = .unique
    }
    return WallClockReply(
      utcEpochMilliseconds: Int64((resolved.timeIntervalSince1970 * 1000).rounded()),
      resolution: resolution
    )
  }

  func replaceReminder(_ request: SafeReminderRequest) async -> FeatureStatusReply {
    guard valid(request) else { return FeatureStatusReply(error: .invalidRequest) }
    let content = UNMutableNotificationContent()
    content.title = "Localhold"
    let russian = Locale.current.languageCode == "ru"
    switch request.privacyCode {
    case 1:
      content.body = russian ? "Напоминание: \(request.safeName!)" : "Reminder: \(request.safeName!)"
    case 2:
      content.body = russian
        ? "Напоминание: \(request.safeName!) · \(request.safeAmount!)"
        : "Reminder: \(request.safeName!) · \(request.safeAmount!)"
    default:
      content.body = russian ? "У вас есть напоминание Localhold" : "You have a Localhold reminder"
    }
    content.categoryIdentifier = Self.reminderCategory
    content.threadIdentifier = "localhold.reminders"
    let interval = TimeInterval(request.utcEpochMilliseconds) / 1000 - Date().timeIntervalSince1970
    guard interval > 0 else { return FeatureStatusReply(error: .invalidRequest) }
    center.removePendingNotificationRequests(withIdentifiers: [request.syntheticId])
    do {
      try await center.add(UNNotificationRequest(
        identifier: request.syntheticId,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
      ))
      return FeatureStatusReply()
    } catch {
      return FeatureStatusReply(error: .internalFailure)
    }
  }

  func cancelReminder(_ syntheticId: String) -> FeatureStatusReply {
    guard Self.idPattern(syntheticId) else { return FeatureStatusReply(error: .invalidRequest) }
    center.removePendingNotificationRequests(withIdentifiers: [syntheticId])
    center.removeDeliveredNotifications(withIdentifiers: [syntheticId])
    return FeatureStatusReply()
  }

  func installLauncherShortcuts() -> FeatureStatusReply {
    MainActor.assumeIsolated {
      UIApplication.shared.shortcutItems = [
        UIApplicationShortcutItem(type: "localhold.add", localizedTitle: "Add", localizedSubtitle: nil,
          icon: UIApplicationShortcutIcon(systemImageName: "plus"), userInfo: nil),
        UIApplicationShortcutItem(type: "localhold.search", localizedTitle: "Search", localizedSubtitle: nil,
          icon: UIApplicationShortcutIcon(type: .search), userInfo: nil),
        UIApplicationShortcutItem(type: "localhold.lock", localizedTitle: "Lock", localizedSubtitle: nil,
          icon: UIApplicationShortcutIcon(systemImageName: "lock"), userInfo: nil),
      ]
      return FeatureStatusReply()
    }
  }

  func acceptLauncherShortcut(_ type: String) -> Bool {
    let value: Int64 = switch type {
    case "localhold.add": 1
    case "localhold.search": 2
    case "localhold.lock": 3
    default: 0
    }
    guard value != 0 else { return false }
    actionLock.lock()
    pendingLauncherAction = value
    actionLock.unlock()
    return true
  }

  func consumeLauncherAction() -> LauncherActionReply {
    actionLock.lock()
    defer { actionLock.unlock() }
    let value = pendingLauncherAction
    pendingLauncherAction = 0
    return LauncherActionReply(actionCode: value)
  }

  func listInboundShares() -> InboundShareListReply { store.list() }
  func readInboundShareChunk(_ request: InboundShareChunkRequest) -> InboundShareChunkReply {
    store.read(request)
  }
  func deleteInboundShare(_ id: String) -> FeatureStatusReply { store.delete(id) }
  func purgeExpiredInboundShares(_ now: Int64) -> FeatureStatusReply { store.purge(now) }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard response.actionIdentifier == Self.snoozeAction else {
      completionHandler()
      return
    }
    let previous = response.notification.request
    center.add(UNNotificationRequest(
      identifier: previous.identifier,
      content: previous.content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
    )) { _ in completionHandler() }
  }

  private func valid(_ value: SafeReminderRequest) -> Bool {
    guard Self.idPattern(value.syntheticId),
          value.utcEpochMilliseconds > Int64(Date().timeIntervalSince1970 * 1000),
          (0...2).contains(value.privacyCode),
          (value.safeName?.count ?? 0) <= 256,
          (value.safeAmount?.count ?? 0) <= 64
    else { return false }
    switch value.privacyCode {
    case 0: return value.safeName == nil && value.safeAmount == nil
    case 1: return !(value.safeName?.isEmpty ?? true) && value.safeAmount == nil
    case 2: return !(value.safeName?.isEmpty ?? true) && !(value.safeAmount?.isEmpty ?? true)
    default: return false
    }
  }

  private func invalidWallClock() -> WallClockReply {
    WallClockReply(utcEpochMilliseconds: 0, resolution: .unique, error: .invalidRequest)
  }

  private static func idPattern(_ value: String) -> Bool {
    value.range(of: "^[A-Za-z0-9_-]{22}$", options: .regularExpression) != nil
  }

  private static let reminderCategory = "localhold.reminder"
  private static let snoozeAction = "localhold.snooze"
}

final class IOSInboundShareStore: @unchecked Sendable {
  private let lock = NSLock()
  private let directory: URL
  private static let idRegex = try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]{22}$")

  init() {
    directory = IOSInboundShareLocation.directory()
      ?? FileManager.default.temporaryDirectory.appendingPathComponent(
        "localhold_inbound_share_unavailable",
        isDirectory: true
      )
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutable = directory
    try? mutable.setResourceValues(values)
  }

  func list() -> InboundShareListReply {
    lock.lock()
    defer { lock.unlock() }
    _ = purgeLocked(Int64(Date().timeIntervalSince1970 * 1000))
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )) ?? []
    return InboundShareListReply(items: urls.filter { $0.pathExtension == "json" }.compactMap(decode))
  }

  func read(_ request: InboundShareChunkRequest) -> InboundShareChunkReply {
    lock.lock()
    defer { lock.unlock() }
    guard Self.validId(request.id), request.offset >= 0,
          (1...65536).contains(request.maximumBytes)
    else { return failure(.invalidRequest) }
    let url = directory.appendingPathComponent("\(request.id).payload")
    guard let handle = try? FileHandle(forReadingFrom: url),
          let size = try? handle.seekToEnd(), UInt64(request.offset) <= size
    else { return failure(.notFound) }
    do {
      try handle.seek(toOffset: UInt64(request.offset))
      let remaining = size - UInt64(request.offset)
      let count = min(Int(request.maximumBytes), Int(remaining))
      let data = try handle.read(upToCount: count) ?? Data()
      try handle.close()
      return InboundShareChunkReply(
        bytes: FlutterStandardTypedData(bytes: data),
        done: UInt64(request.offset) + UInt64(data.count) == size
      )
    } catch {
      try? handle.close()
      return failure(.internalFailure)
    }
  }

  func delete(_ id: String) -> FeatureStatusReply {
    lock.lock()
    defer { lock.unlock() }
    guard Self.validId(id) else { return FeatureStatusReply(error: .invalidRequest) }
    try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).payload"))
    try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).json"))
    return FeatureStatusReply()
  }

  func purge(_ now: Int64) -> FeatureStatusReply {
    lock.lock()
    defer { lock.unlock() }
    return purgeLocked(now)
  }

  private func purgeLocked(_ now: Int64) -> FeatureStatusReply {
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )) ?? []
    for url in urls where url.pathExtension == "json" {
      guard let value = decode(url), value.expiresUtcEpochMilliseconds > now else {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
          at: directory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent).payload")
        )
        continue
      }
    }
    return FeatureStatusReply()
  }

  private func decode(_ url: URL) -> InboundShareDescriptorReply? {
    guard let data = try? Data(contentsOf: url),
          let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let id = value["id"] as? String, Self.validId(id),
          url.deletingPathExtension().lastPathComponent == id,
          let rawKind = value["kind"] as? Int,
          let kind = ShareKindCode(rawValue: rawKind),
          let bytes = value["bytes"] as? Int64,
          let received = value["received"] as? Int64,
          let expires = value["expires"] as? Int64,
          let size = try? directory.appendingPathComponent("\(id).payload")
            .resourceValues(forKeys: [.fileSizeKey]).fileSize,
          Int64(size) == bytes
    else { return nil }
    return InboundShareDescriptorReply(
      id: id,
      kind: kind,
      byteLength: bytes,
      receivedUtcEpochMilliseconds: received,
      expiresUtcEpochMilliseconds: expires
    )
  }

  private func failure(_ error: PlatformFeatureErrorCode) -> InboundShareChunkReply {
    InboundShareChunkReply(
      bytes: FlutterStandardTypedData(bytes: Data()),
      done: true,
      error: error
    )
  }

  private static func validId(_ value: String) -> Bool {
    idRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
  }
}

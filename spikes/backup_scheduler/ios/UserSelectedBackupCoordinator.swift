// SPDX-License-Identifier: MPL-2.0
import BackgroundTasks
import Foundation
import UniformTypeIdentifiers
import UIKit

final class BackupCancellationToken {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

private final class SecurityScopedDirectoryAccess {
    let url: URL
    private let lock = NSLock()
    private var active = true

    init(url: URL) {
        self.url = url
    }

    func stop() {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        active = false
        lock.unlock()
        url.stopAccessingSecurityScopedResource()
    }

    deinit { stop() }
}

private final class BackupCompletionGate {
    private let lock = NSLock()
    private var completed = false
    private let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func complete(_ success: Bool) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        completion(success)
    }
}

final class UserSelectedBackupCoordinator: NSObject, UIDocumentPickerDelegate {
    static let taskIdentifier = "dev.localhold.backup.refresh"

    typealias BackupRun = (
        _ destination: URL,
        _ cancellation: BackupCancellationToken,
        _ completion: @escaping (Bool) -> Void
    ) -> Void

    private let defaults: UserDefaults
    private let bookmarkKey = "localhold.backup.directory.bookmark"
    private let scheduleEnabledKey = "localhold.backup.schedule-enabled"
    private let pendingNextOpenKey = "localhold.backup.pending-next-open"
    private let lastVerifiedKey = "localhold.backup.last-verified-at"
    private let runLock = NSLock()
    private var activeCancellation: BackupCancellationToken?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func makeDirectoryPicker() -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = self
        return picker
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let directory = urls.first else { return }
        guard directory.startAccessingSecurityScopedResource() else {
            defaults.removeObject(forKey: bookmarkKey)
            return
        }
        defer { directory.stopAccessingSecurityScopedResource() }
        do {
            let bookmark = try directory.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: bookmarkKey)
        } catch {
            defaults.removeObject(forKey: bookmarkKey)
        }
    }

    func withSelectedDirectory<T>(_ operation: (URL) throws -> T) throws -> T {
        let access = try acquireSelectedDirectory()
        defer { access.stop() }
        return try operation(access.url)
    }

    private func acquireSelectedDirectory() throws -> SecurityScopedDirectoryAccess {
        guard let data = defaults.data(forKey: bookmarkKey) else {
            throw BackupLocationError.authorizationRequired
        }
        var stale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            defaults.removeObject(forKey: bookmarkKey)
            throw BackupLocationError.authorizationRequired
        }
        guard !stale, url.startAccessingSecurityScopedResource() else {
            defaults.removeObject(forKey: bookmarkKey)
            throw BackupLocationError.authorizationRequired
        }
        let access = SecurityScopedDirectoryAccess(url: url)
        do {
            guard try url.checkResourceIsReachable() else {
                access.stop()
                throw BackupLocationError.providerUnavailable
            }
        } catch let error as BackupLocationError {
            throw error
        } catch {
            access.stop()
            throw BackupLocationError.providerUnavailable
        }
        return access
    }

    /// Must be called during application launch before scheduling any request.
    func registerBackgroundHandler(run: @escaping BackupRun) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let processing = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.executeBackgroundTask(processing, run: run)
        }
    }

    func scheduleBestEffort(earliest: Date, hasPremium: Bool) throws {
        guard hasPremium else { throw BackupLocationError.premiumRequired }
        guard defaults.data(forKey: bookmarkKey) != nil else {
            throw BackupLocationError.authorizationRequired
        }
        defaults.set(true, forKey: scheduleEnabledKey)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = earliest
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        try BGTaskScheduler.shared.submit(request)
    }

    func runPendingOnNextOpen(hasPremium: Bool, run: @escaping BackupRun) throws -> Bool {
        guard defaults.bool(forKey: pendingNextOpenKey) else { return false }
        guard hasPremium else { throw BackupLocationError.premiumRequired }
        let token = BackupCancellationToken()
        guard beginRun(token) else { return false }
        let access: SecurityScopedDirectoryAccess
        do {
            access = try acquireSelectedDirectory()
        } catch {
            endRun(token)
            throw error
        }
        let gate = BackupCompletionGate { [weak self] success in
            access.stop()
            self?.endRun(token)
            self?.finish(success: success)
        }
        run(access.url, token, gate.complete)
        return true
    }

    func disableSchedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        defaults.set(false, forKey: scheduleEnabledKey)
        defaults.set(false, forKey: pendingNextOpenKey)
        runLock.lock()
        let cancellation = activeCancellation
        runLock.unlock()
        cancellation?.cancel()
    }

    var lastVerifiedAt: Date? { defaults.object(forKey: lastVerifiedKey) as? Date }

    private func executeBackgroundTask(_ task: BGProcessingTask, run: @escaping BackupRun) {
        let cancellation = BackupCancellationToken()
        guard beginRun(cancellation) else {
            task.setTaskCompleted(success: false)
            return
        }
        defaults.set(true, forKey: pendingNextOpenKey)
        do {
            let access = try acquireSelectedDirectory()
            let gate = BackupCompletionGate { [weak self] success in
                access.stop()
                self?.endRun(cancellation)
                self?.finish(success: success)
                task.setTaskCompleted(success: success)
            }
            task.expirationHandler = {
                cancellation.cancel()
                gate.complete(false)
            }
            run(access.url, cancellation, gate.complete)
        } catch {
            endRun(cancellation)
            finish(success: false)
            task.setTaskCompleted(success: false)
        }
    }

    private func beginRun(_ cancellation: BackupCancellationToken) -> Bool {
        runLock.lock()
        defer { runLock.unlock() }
        guard activeCancellation == nil else { return false }
        activeCancellation = cancellation
        return true
    }

    private func endRun(_ cancellation: BackupCancellationToken) {
        runLock.lock()
        if activeCancellation === cancellation {
            activeCancellation = nil
        }
        runLock.unlock()
    }

    private func finish(success: Bool) {
        if success {
            defaults.set(Date(), forKey: lastVerifiedKey)
            defaults.set(false, forKey: pendingNextOpenKey)
        } else if defaults.bool(forKey: scheduleEnabledKey) {
            defaults.set(true, forKey: pendingNextOpenKey)
        } else {
            defaults.set(false, forKey: pendingNextOpenKey)
        }
    }
}

enum BackupLocationError: Error {
    case authorizationRequired
    case providerUnavailable
    case premiumRequired
}

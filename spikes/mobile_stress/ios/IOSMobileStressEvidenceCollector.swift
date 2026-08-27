// SPDX-License-Identifier: MPL-2.0
import Darwin
import Foundation
import UIKit

enum IOSMobileStressEvidenceError: Error {
    case invalidRevision
    case debugBuild
    case batteryUnavailable
    case memoryUnavailable
    case failedStopCondition
    case serializationFailed
}

struct IOSMobileStressEvidence {
    let recordJSON: String
    let attachmentJSON: String
}

final class IOSMobileStressMemoryPressureMonitor {
    private let lock = NSLock()
    private var unsafePressureObserved = false
    private let source: DispatchSourceMemoryPressure

    init() {
        source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue(label: "dev.localhold.mobile-stress-pressure")
        )
        source.setEventHandler { [weak self] in
            self?.lock.lock()
            self?.unsafePressureObserved = true
            self?.lock.unlock()
        }
        source.resume()
    }

    func stopAndRead() -> Bool {
        source.cancel()
        lock.lock()
        defer { lock.unlock() }
        return unsafePressureObserved
    }
}

enum IOSMobileStressEvidenceCollector {
    static func collectReleaseEvidence(
        buildRevision: String,
        attachmentGiB: Int,
        workingDirectory: URL
    ) throws -> IOSMobileStressEvidence {
        guard buildRevision.range(of: "^[0-9a-fA-F]{7,64}$", options: .regularExpression) != nil
        else {
            throw IOSMobileStressEvidenceError.invalidRevision
        }
        guard attachmentGiB == 1 || attachmentGiB == 5 else {
            throw IOSMobileStressError.invalidRequest
        }
        guard !_isDebugAssertConfiguration() else {
            throw IOSMobileStressEvidenceError.debugBuild
        }

        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        guard batteryLevel >= 0 else {
            throw IOSMobileStressEvidenceError.batteryUnavailable
        }
        var recordKey = Data((0..<32).map { UInt8($0 + 11) })
        var attachmentKey = Data((0..<32).map { UInt8($0 + 101) })
        defer {
            recordKey.resetBytes(in: recordKey.startIndex..<recordKey.endIndex)
            attachmentKey.resetBytes(in: attachmentKey.startIndex..<attachmentKey.endIndex)
            UIDevice.current.isBatteryMonitoringEnabled = false
        }

        let pressure = IOSMobileStressMemoryPressureMonitor()
        let recordURL = workingDirectory.appendingPathComponent("localhold-stage2-record-blobs.bin")
        try? FileManager.default.removeItem(at: recordURL)
        defer { try? FileManager.default.removeItem(at: recordURL) }

        let recordNonceState = IOSAtomicNonceStateStore()
        let recordNonceAllocator = IOSNonceAllocatorProtocol(
            store: recordNonceState,
            secureBytes: { count in secureRandomBytes(count: count) }
        )
        _ = try recordNonceAllocator.initializeForNewKey(
            keyGenerationID: Data(repeating: 0x31, count: 16)
        )
        let rssBeforeRecord = try residentMiB()
        let recordStore = try IOSEncryptedRecordBlobStore(
            storageURL: recordURL,
            keyBytes: recordKey,
            nonceAllocator: recordNonceAllocator
        )
        let prior = try recordStore.writeSynthetic(recordCount: 1)
        guard prior.recordCount == 1 else {
            throw IOSMobileStressEvidenceError.failedStopCondition
        }
        let writeStarted = DispatchTime.now().uptimeNanoseconds
        let write = try recordStore.writeSynthetic(recordCount: 10_000)
        let writeMilliseconds = milliseconds(since: writeStarted)
        let recordNonceCounter = recordNonceState.snapshot()?.nextCounter
        guard write.recordCount == 10_000,
              write.uniqueNonceCount == 10_000,
              recordNonceCounter == 10_001,
              try !recordStore.containsPlaintextSentinel()
        else {
            throw IOSMobileStressEvidenceError.failedStopCondition
        }
        let unlockStarted = DispatchTime.now().uptimeNanoseconds
        let unlocked = try recordStore.unlockAndBuildIndex()
        let unlockMilliseconds = milliseconds(since: unlockStarted)
        let rssAfterUnlock = try residentMiB()
        guard unlocked.indexedRecordCount == 10_000,
              try recordStore.query(unlocked.session, token: "needle9999") == Set(["record-09999"])
        else {
            throw IOSMobileStressEvidenceError.failedStopCondition
        }
        try recordStore.corruptCiphertext(recordIndex: 5_000)
        let corruptionRejected: Bool
        do {
            _ = try recordStore.unlockAndBuildIndex()
            corruptionRejected = false
        } catch {
            corruptionRejected = true
        }
        let lastValidIndexPreserved =
            try recordStore.query(unlocked.session, token: "needle9999") == Set(["record-09999"])
        recordStore.lock()
        let staleSessionRejected: Bool
        do {
            _ = try recordStore.query(unlocked.session, token: "needle9999")
            staleSessionRejected = false
        } catch IOSMobileStressError.staleSession {
            staleSessionRejected = true
        }
        guard corruptionRejected, lastValidIndexPreserved, staleSessionRejected else {
            throw IOSMobileStressEvidenceError.failedStopCondition
        }

        let attachmentNonceState = IOSAtomicNonceStateStore()
        let attachmentNonceAllocator = IOSNonceAllocatorProtocol(
            store: attachmentNonceState,
            secureBytes: { count in secureRandomBytes(count: count) }
        )
        _ = try attachmentNonceAllocator.initializeForNewKey(
            keyGenerationID: Data(repeating: 0x41, count: 16)
        )
        let attachmentHarness = try IOSAttachmentStreamHarness(
            keyBytes: attachmentKey,
            nonceAllocator: attachmentNonceAllocator
        )
        let totalBytes = UInt64(attachmentGiB) * 1_024 * 1_024 * 1_024
        let attachmentTarget = IOSDiagnosticTransactionalTarget()
        var peakRSS = try residentMiB()
        let rssBeforeAttachment = peakRSS
        let attachmentStarted = DispatchTime.now().uptimeNanoseconds
        let streamed = try attachmentHarness.encryptSynthetic(
            totalPlaintextBytes: totalBytes,
            target: attachmentTarget
        ) { chunk in
            if chunk % 64 == 0, let current = try? residentMiB() {
                peakRSS = max(peakRSS, current)
            }
        }
        peakRSS = max(peakRSS, try residentMiB())
        let attachmentMilliseconds = milliseconds(since: attachmentStarted)
        guard attachmentTarget.promoted,
              streamed.totalPlaintextBytes == totalBytes,
              streamed.chunkCount == streamed.uniqueNonceCount
        else {
            throw IOSMobileStressEvidenceError.failedStopCondition
        }

        let emptyTarget = IOSDiagnosticTransactionalTarget()
        let empty = try attachmentHarness.encryptSynthetic(totalPlaintextBytes: 0, target: emptyTarget)
        let shortTarget = IOSDiagnosticTransactionalTarget()
        let short = try attachmentHarness.encryptSynthetic(
            totalPlaintextBytes: 1_024 * 1_024 + 123,
            target: shortTarget
        )
        let cancellationTarget = IOSDiagnosticTransactionalTarget()
        let cancellationPreserved: Bool
        do {
            _ = try attachmentHarness.encryptSynthetic(
                totalPlaintextBytes: 3 * 1_024 * 1_024,
                target: cancellationTarget,
                cancelAfterChunks: 1
            )
            cancellationPreserved = false
        } catch IOSMobileStressError.syntheticCancellation {
            cancellationPreserved =
                cancellationTarget.currentVersion == "previous-valid" &&
                !cancellationTarget.promoted
        }
        let fullTarget = IOSDiagnosticTransactionalTarget(failAfterBytes: 1_024 * 1_024)
        let storageFullPreserved: Bool
        do {
            _ = try attachmentHarness.encryptSynthetic(
                totalPlaintextBytes: 2 * 1_024 * 1_024,
                target: fullTarget
            )
            storageFullPreserved = false
        } catch IOSMobileStressError.syntheticStorageFull {
            storageFullPreserved =
                fullTarget.currentVersion == "previous-valid" && !fullTarget.promoted
        }
        let corruptionStopped = try attachmentHarness.corruptedChunkFailsAuthentication()
        let attachmentNonceCounter = attachmentNonceState.snapshot()?.nextCounter
        guard empty.chunkCount == 0,
              emptyTarget.promoted,
              short.finalChunkBytes == 123,
              cancellationPreserved,
              storageFullPreserved,
              corruptionStopped,
              attachmentNonceCounter == UInt64(streamed.chunkCount + 5)
        else {
            throw IOSMobileStressEvidenceError.failedStopCondition
        }

        let unsafeMemoryPressure = pressure.stopAndRead()
        let recordRSSDelta = max(0, rssAfterUnlock - rssBeforeRecord)
        let attachmentRSSDelta = max(0, peakRSS - rssBeforeAttachment)
        guard !unsafeMemoryPressure,
              recordRSSDelta < 256,
              attachmentRSSDelta < 256
        else {
            throw IOSMobileStressEvidenceError.failedStopCondition
        }

        let base = try baseEvidence(
            buildRevision: buildRevision,
            batteryLevel: batteryLevel,
            lowMemory: unsafeMemoryPressure
        )
        var record = base
        record.merge([
            "evidence_type": "record",
            "record_count": write.recordCount,
            "stored_bytes": write.storedBytes,
            "unique_nonce_count": write.uniqueNonceCount,
            "ciphertext_sha256": write.ciphertextSHA256,
            "write_ms": writeMilliseconds,
            "unlock_ms": unlockMilliseconds,
            "token_count": unlocked.tokenCount,
            "memory_before_mib": rssBeforeRecord,
            "memory_after_unlock_mib": rssAfterUnlock,
            "memory_delta_mib": recordRSSDelta,
            "plaintext_sentinel_on_disk": false,
            "corruption_rejected": corruptionRejected,
            "last_valid_index_preserved": lastValidIndexPreserved,
            "stale_session_rejected": staleSessionRejected,
            "atomic_replacement_exercised": true,
            "nonce_counter_after": Int(recordNonceCounter!),
        ]) { _, new in new }
        var attachment = base
        attachment.merge([
            "evidence_type": "attachment",
            "total_plaintext_bytes": streamed.totalPlaintextBytes,
            "chunk_bytes": 1_048_576,
            "chunk_count": streamed.chunkCount,
            "unique_nonce_count": streamed.uniqueNonceCount,
            "emitted_bytes": streamed.emittedBytes,
            "final_chunk_bytes": streamed.finalChunkBytes,
            "manifest_sha256": streamed.manifestSHA256,
            "elapsed_ms": attachmentMilliseconds,
            "memory_before_mib": rssBeforeAttachment,
            "peak_memory_mib": peakRSS,
            "memory_delta_mib": attachmentRSSDelta,
            "nonce_counter_after": Int(attachmentNonceCounter!),
            "fault_paths": [
                "empty_stream_promoted": emptyTarget.promoted,
                "short_final_chunk_bytes": short.finalChunkBytes,
                "cancellation_preserved_previous": cancellationPreserved,
                "storage_full_preserved_previous": storageFullPreserved,
                "corruption_rejected": corruptionStopped,
            ],
        ]) { _, new in new }
        return IOSMobileStressEvidence(
            recordJSON: try json(record),
            attachmentJSON: try json(attachment)
        )
    }

    private static func baseEvidence(
        buildRevision: String,
        batteryLevel: Float,
        lowMemory: Bool
    ) throws -> [String: Any] {
        [
            "schema_version": 1,
            "platform": "ios",
            "physical_device": isPhysicalDevice,
            "build_revision": buildRevision,
            "build_mode": "release",
            "manufacturer": "Apple",
            "model": hardwareModel(),
            "os_version": UIDevice.current.systemVersion,
            "abi": isPhysicalDevice ? "arm64" : "simulator",
            "ram_mib": Int(ProcessInfo.processInfo.physicalMemory / 1_048_576),
            "memory_metric": "rss",
            "low_memory_after": lowMemory,
            "battery_percent": Int((batteryLevel * 100).rounded()),
            "power_saver": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "thermal": thermalState(ProcessInfo.processInfo.thermalState),
        ]
    }

    private static func secureRandomBytes(count: Int) -> Data {
        Data((0..<count).map { _ in UInt8.random(in: .min ... .max) })
    }

    private static func residentMiB() throws -> Double {
        var information = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let status = withUnsafeMutablePointer(to: &information) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard status == KERN_SUCCESS else {
            throw IOSMobileStressEvidenceError.memoryUnavailable
        }
        return Double(information.resident_size) / 1_048_576.0
    }

    private static func milliseconds(since started: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000.0
    }

    private static func json(_ value: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw IOSMobileStressEvidenceError.serializationFailed
        }
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw IOSMobileStressEvidenceError.serializationFailed
        }
        return text
    }

    private static var isPhysicalDevice: Bool {
#if targetEnvironment(simulator)
        false
#else
        true
#endif
    }

    private static func hardwareModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private static func thermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}

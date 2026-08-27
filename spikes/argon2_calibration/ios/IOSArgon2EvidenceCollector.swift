// SPDX-License-Identifier: MPL-2.0
import Foundation
import UIKit

enum IOSArgon2EvidenceError: Error {
    case invalidRevision
    case debugBuild
    case batteryUnavailable
    case serializationFailed
}

final class IOSMemoryPressureMonitor {
    private let lock = NSLock()
    private var unsafePressureObserved = false
    private let source: DispatchSourceMemoryPressure

    init() {
        source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue(label: "dev.localhold.argon2-memory-pressure")
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

enum IOSArgon2EvidenceCollector {
    static func collectReleaseEvidence(
        buildRevision: String,
        memoryKiB: Int,
        operations: UInt64
    ) throws -> String {
        guard buildRevision.range(of: "^[0-9a-fA-F]{7,64}$", options: .regularExpression) != nil
        else {
            throw IOSArgon2EvidenceError.invalidRevision
        }
        guard !_isDebugAssertConfiguration() else {
            throw IOSArgon2EvidenceError.debugBuild
        }

        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        guard batteryLevel >= 0 else {
            throw IOSArgon2EvidenceError.batteryUnavailable
        }

        var password = Array("localhold-stage2-synthetic-password".utf8)
        var salt = (1...16).map(UInt8.init)
        defer {
            password.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) }
            salt.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) }
            UIDevice.current.isBatteryMonitoringEnabled = false
        }

        let pressureMonitor = IOSMemoryPressureMonitor()
        let thermalBefore = thermalState(ProcessInfo.processInfo.thermalState)
        for _ in 0..<5 {
            _ = try IOSArgon2Calibration.runSynthetic(
                password: password,
                salt: salt,
                memoryKiB: memoryKiB,
                operations: operations,
                sampleCount: 1
            )
        }
        let measured = try IOSArgon2Calibration.runSynthetic(
            password: password,
            salt: salt,
            memoryKiB: memoryKiB,
            operations: operations,
            sampleCount: 30
        )
        var stressSuccessfulRuns = 0
        for _ in 0..<20 {
            let stress = try IOSArgon2Calibration.runSynthetic(
                password: password,
                salt: salt,
                memoryKiB: memoryKiB,
                operations: operations,
                sampleCount: 1
            )
            guard stress.outputSHA256 == measured.outputSHA256 else {
                throw IOSArgon2CalibrationError.hashFailed
            }
            stressSuccessfulRuns += 1
        }
        let unsafeMemoryPressure = pressureMonitor.stopAndRead()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let document: [String: Any] = [
            "schema_version": 1,
            "run_id": UUID().uuidString,
            "recorded_at": formatter.string(from: Date()),
            "platform": "ios",
            "physical_device": isPhysicalDevice,
            "device": [
                "manufacturer": "Apple",
                "model": hardwareModel(),
                "os_version": UIDevice.current.systemVersion,
                "abi": isPhysicalDevice ? "arm64" : "simulator",
                "ram_mib": Int(ProcessInfo.processInfo.physicalMemory / 1_048_576),
            ],
            "build": [
                "revision": buildRevision,
                "mode": "release",
            ],
            "library": [
                "name": "libsodium",
                "version": "1.0.21",
                "source_sha256": "9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf",
            ],
            "profile": [
                "algorithm": "argon2id",
                "version": 19,
                "memory_kib": memoryKiB,
                "operations": Int(operations),
                "parallelism": 1,
                "salt_bytes": 16,
                "output_bytes": 32,
            ],
            "timing": [
                "warmup_count": 5,
                "samples_ms": measured.samplesNanoseconds.map { Double($0) / 1_000_000.0 },
                "stress_successful_runs": stressSuccessfulRuns,
            ],
            "safety": [
                "oom": false,
                "crash": false,
                "anr": false,
                "safe_memory_pressure": !unsafeMemoryPressure,
                "battery_percent": Int((batteryLevel * 100).rounded()),
                "power_saver": ProcessInfo.processInfo.isLowPowerModeEnabled,
                "thermal_before": thermalBefore,
                "thermal_after": thermalState(ProcessInfo.processInfo.thermalState),
                "peak_rss_delta_mib": NSNull(),
            ],
            "vector": [
                "id": "localhold-argon2id-synthetic-v1",
                "output_sha256": measured.outputSHA256,
            ],
        ]
        guard JSONSerialization.isValidJSONObject(document) else {
            throw IOSArgon2EvidenceError.serializationFailed
        }
        let data = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw IOSArgon2EvidenceError.serializationFailed
        }
        return json
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

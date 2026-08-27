# SPDX-License-Identifier: MPL-2.0
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
ANDROID = ROOT / "android"
MAIN_KOTLIN = list((ANDROID / "app" / "src" / "main" / "kotlin").rglob("*.kt"))
TEST_KOTLIN = list((ANDROID / "app" / "src" / "androidTest" / "kotlin").rglob("*.kt"))
MANIFEST = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
GRADLE = ANDROID / "app" / "build.gradle.kts"
RUNNER = ROOT / "tool" / "run_physical_adb.ps1"
IOS_HARNESS = ROOT / "ios" / "IOSMobileStressHarness.swift"
IOS_EVIDENCE = ROOT / "ios" / "IOSMobileStressEvidenceCollector.swift"
IOS_VERIFIER = ROOT / "ios" / "verify_host.swift"
NONCE_ROOT = ROOT.parent / "nonce_allocator"
NONCE_README = NONCE_ROOT / "README.md"
NONCE_SWIFT = NONCE_ROOT / "ios" / "IOSNonceAllocatorProtocol.swift"
NONCE_SWIFT_VERIFIER = NONCE_ROOT / "ios" / "verify_nonce_allocator.swift"
WORKFLOW = ROOT.parents[2] / ".github" / "workflows" / "stage2-ios-spikes.yml"


class MobileStressSourceBoundaryTests(unittest.TestCase):
    def test_sources_have_license_markers(self) -> None:
        for path in MAIN_KOTLIN + TEST_KOTLIN + [
            RUNNER,
            IOS_HARNESS,
            IOS_EVIDENCE,
            IOS_VERIFIER,
            NONCE_SWIFT,
            NONCE_SWIFT_VERIFIER,
        ]:
            self.assertIn("SPDX-License-Identifier: MPL-2.0", path.read_text(encoding="utf-8"), path)

    def test_application_has_no_network_or_logging_boundary(self) -> None:
        combined = "\n".join(path.read_text(encoding="utf-8") for path in MAIN_KOTLIN)
        manifest = MANIFEST.read_text(encoding="utf-8")
        for marker in ("android.permission.INTERNET", "URLSession", "OkHttp", "HttpURLConnection"):
            self.assertNotIn(marker, combined + manifest)
        for marker in ("android.util.Log", "println("):
            self.assertNotIn(marker, combined)

    def test_release_instrumentation_is_required(self) -> None:
        gradle = GRADLE.read_text(encoding="utf-8")
        self.assertIn('testBuildType = "release"', gradle)
        self.assertIn('getByName("release")', gradle)
        self.assertIn("isDebuggable = false", gradle)
        combined = "\n".join(path.read_text(encoding="utf-8") for path in TEST_KOTLIN)
        self.assertIn('Build.SUPPORTED_ABIS.firstOrNull() == "arm64-v8a"', combined)

    def test_physical_adb_runner_is_narrow_and_service_neutral(self) -> None:
        runner = RUNNER.read_text(encoding="utf-8")
        self.assertIn("git -C $repositoryRoot rev-parse HEAD", runner)
        self.assertIn("git -C $repositoryRoot status --porcelain", runner)
        self.assertIn("clean working tree", runner)
        self.assertIn("#selectedPhysicalEvidence", runner)
        self.assertIn("ro.kernel.qemu", runner)
        self.assertIn("ro.product.cpu.abi", runner)
        self.assertIn("ro.build.hv.platform", runner)
        self.assertIn("127\\.0\\.0\\.1|localhost", runner)
        self.assertIn("Exactly one authorized ADB device", runner)
        self.assertIn("validate_results.py", runner)
        self.assertIn("selectel-mobile-farm", runner)
        self.assertNotIn("huawei-cloud-debugging", runner)
        self.assertNotIn("firebase", runner.lower())
        self.assertNotIn("gcloud", runner.lower())

    def test_record_and_attachment_stop_conditions_are_present(self) -> None:
        combined = "\n".join(path.read_text(encoding="utf-8") for path in MAIN_KOTLIN + TEST_KOTLIN)
        for marker in (
            "containsPlaintextSentinel",
            "corruptCiphertext",
            "stale record search session",
            "attachment nonce reuse",
            "synthetic storage full",
            "CancellationException",
            "AEADBadTagException",
        ):
            self.assertIn(marker, combined)

    def test_api24_atomic_publisher_has_versioned_posix_fallback(self) -> None:
        record_store = next(path for path in MAIN_KOTLIN if path.name == "EncryptedRecordBlobStore.kt")
        source = record_store.read_text(encoding="utf-8")
        for marker in (
            "AndroidAtomicFilePublisher",
            "Build.VERSION.SDK_INT >= Build.VERSION_CODES.O",
            "StandardCopyOption.ATOMIC_MOVE",
            "Os.rename",
            "atomic replacement requires one directory",
        ):
            self.assertIn(marker, source)
        publisher = source[source.index("internal object AndroidAtomicFilePublisher") :]
        self.assertNotIn("destination.delete", publisher)

    def test_ios_harness_has_equivalent_host_and_device_ci_boundary(self) -> None:
        source = IOS_HARNESS.read_text(encoding="utf-8")
        evidence = IOS_EVIDENCE.read_text(encoding="utf-8")
        verifier = IOS_VERIFIER.read_text(encoding="utf-8")
        workflow = WORKFLOW.read_text(encoding="utf-8")
        for marker in (
            "AES.GCM.seal",
            "AES.GCM.open",
            "recordCount: 10_000",
            "syntheticCancellation",
            "syntheticStorageFull",
            "corruptedChunkFailsAuthentication",
        ):
            self.assertIn(marker, source + evidence + verifier)
        for marker in (
            "collectReleaseEvidence",
            "attachmentGiB == 1 || attachmentGiB == 5",
            "physical_device",
            '"memory_metric": "rss"',
            "memory_delta_mib",
            "battery_percent",
            "low_memory_after",
        ):
            self.assertIn(marker, evidence)
        self.assertNotIn("URLSession", source + evidence)
        self.assertIn("verify_mobile_stress", workflow)
        self.assertIn("-target arm64-apple-ios15.0", workflow)
        self.assertIn("IOSMobileStressEvidenceCollector.swift", workflow)
        self.assertIn("IOSNonceAllocatorProtocol.swift", workflow)
        self.assertIn("nonceAllocator.reserve()", source)
        self.assertIn('"nonce_counter_after"', evidence)
        self.assertIn("recordKey", evidence)
        self.assertIn("attachmentKey", evidence)

    def test_native_nonce_protocol_has_parallel_fault_and_rotation_gates(self) -> None:
        kotlin = "\n".join(path.read_text(encoding="utf-8") for path in MAIN_KOTLIN)
        swift = NONCE_SWIFT.read_text(encoding="utf-8")
        verifier = NONCE_SWIFT_VERIFIER.read_text(encoding="utf-8")
        readme = NONCE_README.read_text(encoding="utf-8")
        workflow = WORKFLOW.read_text(encoding="utf-8")
        for marker in (
            "AFTER_COMMIT_BEFORE_RETURN",
            "ULong.MAX_VALUE",
            "initializeForNewKey",
            "rotateAfterKeyChange",
            "synchronized(monitor)",
        ):
            self.assertIn(marker, kotlin)
        for marker in (
            "afterCommitBeforeReturn",
            "UInt64.max",
            "initializeForNewKey",
            "missingState",
            "rotateAfterKeyChange",
            "keyGenerationNotChanged",
            "DispatchQueue.concurrentPerform",
        ):
            self.assertIn(marker, swift + verifier)
        self.assertIn("does not claim that an in-memory test store is a production", readme)
        self.assertNotIn("URLSession", swift + verifier)
        self.assertIn("verify_nonce_allocator", workflow)


if __name__ == "__main__":
    unittest.main()

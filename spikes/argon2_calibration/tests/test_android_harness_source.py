# SPDX-License-Identifier: MPL-2.0
from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
C_SOURCE = ROOT / "android" / "harness" / "src" / "main" / "cpp" / "localhold_argon2_calibration.c"
KOTLIN_SOURCE = ROOT / "android" / "harness" / "src" / "main" / "kotlin" / "dev" / "localhold" / "argon2" / "calibration" / "NativeArgon2Calibration.kt"
GRADLE_SOURCE = ROOT / "android" / "harness" / "build.gradle.kts"
CMAKE_SOURCE = ROOT / "android" / "harness" / "src" / "main" / "cpp" / "CMakeLists.txt"
VERIFIED_BUILD_SCRIPT = ROOT / "tool" / "build_verified_mobile_archives.sh"
VERIFIED_APPLE_BUILD_SCRIPT = ROOT / "tool" / "build_verified_apple_xcframework.sh"
PHYSICAL_RUN_SCRIPT = ROOT / "tool" / "run_physical_adb.ps1"
EMULATOR_TEST_SOURCE = ROOT / "emulator_app" / "app" / "src" / "androidTest" / "kotlin" / "dev" / "localhold" / "argon2" / "calibration" / "ArgonCalibrationInstrumentedTest.kt"
EMULATOR_GRADLE_SOURCE = ROOT / "emulator_app" / "app" / "build.gradle.kts"
IOS_SOURCE = ROOT / "ios" / "IOSArgon2Calibration.swift"
IOS_VECTOR_SOURCE = ROOT / "ios" / "verify_synthetic_vector.swift"
IOS_EVIDENCE_SOURCE = ROOT / "ios" / "IOSArgon2EvidenceCollector.swift"


class AndroidHarnessBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.c_source = C_SOURCE.read_text(encoding="utf-8")
        cls.kotlin_source = KOTLIN_SOURCE.read_text(encoding="utf-8")
        cls.gradle_source = GRADLE_SOURCE.read_text(encoding="utf-8")
        cls.cmake_source = CMAKE_SOURCE.read_text(encoding="utf-8")
        cls.verified_build_script = VERIFIED_BUILD_SCRIPT.read_text(encoding="utf-8")
        cls.verified_apple_build_script = VERIFIED_APPLE_BUILD_SCRIPT.read_text(encoding="utf-8")
        cls.physical_run_script = PHYSICAL_RUN_SCRIPT.read_text(encoding="utf-8")
        cls.emulator_test_source = EMULATOR_TEST_SOURCE.read_text(encoding="utf-8")
        cls.emulator_gradle_source = EMULATOR_GRADLE_SOURCE.read_text(encoding="utf-8")
        cls.ios_source = IOS_SOURCE.read_text(encoding="utf-8")
        cls.ios_vector_source = IOS_VECTOR_SOURCE.read_text(encoding="utf-8")
        cls.ios_evidence_source = IOS_EVIDENCE_SOURCE.read_text(encoding="utf-8")

    def test_explicit_argon2id_and_approved_grid(self) -> None:
        self.assertIn("crypto_pwhash_ALG_ARGON2ID13", self.c_source)
        for value in ("65536", "98304", "131072"):
            self.assertIn(value, self.c_source)
        self.assertRegex(self.c_source, r"operations == 2.*operations == 3.*operations == 4")

    def test_raw_output_is_not_returned(self) -> None:
        self.assertIn("crypto_hash_sha256(output_hash, output", self.c_source)
        self.assertNotIn("NewByteArray", self.c_source)
        self.assertEqual(self.kotlin_source.count("external fun"), 1)
        self.assertIn("): String", self.kotlin_source)

    def test_sensitive_buffers_are_wiped(self) -> None:
        for buffer_name in ("password", "salt", "output", "output_hash", "json"):
            self.assertRegex(self.c_source, rf"sodium_memzero\({buffer_name}\b")

    def test_harness_has_no_logging_or_network_api(self) -> None:
        combined = "\n".join((self.c_source, self.kotlin_source, self.gradle_source))
        forbidden = (
            "__android_log",
            "android.util.Log",
            "println(",
            "http://",
            "https://",
            "INTERNET",
        )
        for marker in forbidden:
            self.assertNotIn(marker, combined)

    def test_only_verified_local_aar_is_linked(self) -> None:
        self.assertIn('files("../libs/libsodium-1.0.21.0.aar")', self.gradle_source)
        self.assertNotRegex(self.gradle_source, r"implementation\(\s*\"[^\"]+:[^\"]+:[^\"]+\"")
        self.assertIn("sodium::sodium-minimal-static", self.cmake_source)

    def test_native_hardening_flags_are_required(self) -> None:
        for flag in ("-Werror", "-fstack-protector-strong", "-Wl,-z,relro", "-Wl,-z,now", "-Wl,-z,noexecstack"):
            self.assertIn(flag, self.cmake_source)

    def test_mobile_archive_build_fails_without_signature_verification(self) -> None:
        self.assertIn("minisign -Vm", self.verified_build_script)
        self.assertIn("RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3", self.verified_build_script)
        self.assertIn("9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf", self.verified_build_script)
        self.assertNotIn("--insecure", self.verified_build_script)
        self.assertIn("NDK_PLATFORM=\"android-24\"", self.verified_build_script)

    def test_physical_evidence_uses_release_build_and_required_sample_counts(self) -> None:
        self.assertIn('testBuildType = "release"', self.emulator_gradle_source)
        self.assertIn('getByName("release")', self.emulator_gradle_source)
        for marker in ("repeat(5)", "runNative(memoryKib, operations, 30)", "repeat(20)"):
            self.assertIn(marker, self.emulator_test_source)
        self.assertIn("localholdUtf8VectorsMatchWithoutNormalization", self.emulator_test_source)
        for vector_id in ("cyrillic", "emoji", "nfc", "nfd"):
            self.assertIn(f'"{vector_id}"', self.emulator_test_source)
        self.assertIn("LOCALHOLD_ARGON2_EVIDENCE", self.emulator_test_source)
        self.assertIn("localhold-stage2-synthetic-password", self.emulator_test_source)
        self.assertIn("ByteArray(1_025)", self.emulator_test_source)
        self.assertIn("assertInvalid", self.emulator_test_source)
        self.assertIn("synthetic-passw0rd", self.emulator_test_source)
        self.assertIn('Build.SUPPORTED_ABIS.firstOrNull() == "arm64-v8a"', self.emulator_test_source)

    def test_physical_adb_script_is_narrow_and_requires_traceable_revision(self) -> None:
        self.assertIn("git -C $repositoryRoot rev-parse HEAD", self.physical_run_script)
        self.assertIn("git -C $repositoryRoot status --porcelain", self.physical_run_script)
        self.assertIn("clean working tree", self.physical_run_script)
        self.assertIn("#selectedProfileProducesSchemaReadyEvidence", self.physical_run_script)
        self.assertIn("#localholdUtf8VectorsMatchWithoutNormalization", self.physical_run_script)
        self.assertIn("ro.kernel.qemu", self.physical_run_script)
        self.assertIn("ro.product.cpu.abi", self.physical_run_script)
        self.assertIn("ro.build.hv.platform", self.physical_run_script)
        self.assertIn("127\\.0\\.0\\.1|localhost", self.physical_run_script)
        self.assertIn("Exactly one authorized ADB device", self.physical_run_script)
        self.assertIn("extract_android_result.py", self.physical_run_script)
        self.assertIn("selectel-mobile-farm", self.physical_run_script)
        self.assertNotIn("huawei-cloud-debugging", self.physical_run_script)
        self.assertNotIn("firebase", self.physical_run_script.lower())
        self.assertNotIn("gcloud", self.physical_run_script.lower())

    def test_apple_build_and_argon_boundary_use_the_same_pinned_source(self) -> None:
        for marker in (
            "9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf",
            "minisign -Vm",
            "apple-xcframework.sh",
            "Clibsodium.xcframework",
            "make check",
        ):
            self.assertIn(marker, self.verified_apple_build_script)
        self.assertIn("crypto_pwhash_ALG_ARGON2ID13", self.ios_source)
        self.assertGreaterEqual(self.ios_source.count("sodium_memzero"), 3)
        self.assertNotIn("URLSession", self.ios_source)
        self.assertIn(
            "39bf18e5fdc7044a024f188e65b6ab5b8f65a607748ee5dd0ae57e5521a8ee54",
            self.ios_vector_source,
        )

    def test_ios_evidence_collector_is_release_only_and_schema_shaped(self) -> None:
        self.assertIn("!_isDebugAssertConfiguration()", self.ios_evidence_source)
        self.assertIn("for _ in 0..<5", self.ios_evidence_source)
        self.assertIn("sampleCount: 30", self.ios_evidence_source)
        self.assertIn("for _ in 0..<20", self.ios_evidence_source)
        self.assertIn("#if targetEnvironment(simulator)", self.ios_evidence_source)
        self.assertIn("safe_memory_pressure", self.ios_evidence_source)
        self.assertNotIn("URLSession", self.ios_evidence_source)


if __name__ == "__main__":
    unittest.main()

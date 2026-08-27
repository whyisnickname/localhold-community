# SPDX-License-Identifier: MPL-2.0
from __future__ import annotations

import copy
import importlib.util
import math
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "tools" / "validate_result.py"
SPEC = importlib.util.spec_from_file_location("validate_result", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def valid_document() -> dict:
    return {
        "schema_version": 1,
        "run_id": "android-low-memory-001",
        "recorded_at": "2026-08-22T12:00:00+03:00",
        "platform": "android",
        "physical_device": True,
        "device": {
            "manufacturer": "Synthetic",
            "model": "Test device",
            "os_version": "Test OS 1",
            "abi": "arm64-v8a",
            "ram_mib": 2048,
        },
        "build": {"revision": "abcdef012345", "mode": "release"},
        "library": {
            "name": "libsodium",
            "version": "pinned-test",
            "source_sha256": "a" * 64,
        },
        "profile": {
            "algorithm": "argon2id",
            "version": 19,
            "memory_kib": 65536,
            "operations": 3,
            "parallelism": 1,
            "salt_bytes": 16,
            "output_bytes": 32,
        },
        "timing": {
            "warmup_count": 5,
            "samples_ms": [500 + index for index in range(30)],
            "stress_successful_runs": 20,
        },
        "safety": {
            "oom": False,
            "crash": False,
            "anr": False,
            "safe_memory_pressure": True,
            "battery_percent": 80,
            "power_saver": False,
            "thermal_before": "nominal",
            "thermal_after": "nominal",
            "peak_rss_delta_mib": 70.5,
        },
        "vector": {"id": "synthetic-ascii-01", "output_sha256": "b" * 64},
    }


class ValidationTests(unittest.TestCase):
    def test_valid_physical_result_is_eligible(self) -> None:
        assessment = MODULE.validate_result(valid_document())
        self.assertTrue(assessment["release_eligible"])
        self.assertEqual(assessment["sample_count"], 30)
        self.assertEqual(assessment["median_ms"], 514.5)
        self.assertEqual(assessment["p95_ms"], 528.0)

    def test_diagnostic_emulator_result_is_valid_but_not_eligible(self) -> None:
        document = valid_document()
        document["physical_device"] = False
        assessment = MODULE.validate_result(document)
        self.assertTrue(assessment["valid"])
        self.assertFalse(assessment["release_eligible"])

    def test_profile_below_floor_is_not_eligible(self) -> None:
        document = valid_document()
        document["profile"]["operations"] = 2
        assessment = MODULE.validate_result(document)
        self.assertFalse(assessment["floor_met"])
        self.assertFalse(assessment["release_eligible"])

    def test_incomplete_samples_are_rejected(self) -> None:
        document = valid_document()
        document["timing"]["samples_ms"] = [500] * 29
        with self.assertRaisesRegex(MODULE.ValidationError, "at least 30"):
            MODULE.validate_result(document)

    def test_non_finite_sample_is_rejected(self) -> None:
        document = valid_document()
        document["timing"]["samples_ms"][4] = math.inf
        with self.assertRaisesRegex(MODULE.ValidationError, "outside"):
            MODULE.validate_result(document)

    def test_timestamp_without_offset_is_rejected(self) -> None:
        document = valid_document()
        document["recorded_at"] = "2026-08-22T12:00:00"
        with self.assertRaisesRegex(MODULE.ValidationError, "UTC offset"):
            MODULE.validate_result(document)

    def test_failure_evidence_is_valid_but_not_eligible(self) -> None:
        document = valid_document()
        document["safety"]["oom"] = True
        document["timing"]["stress_successful_runs"] = 3
        assessment = MODULE.validate_result(document)
        self.assertFalse(assessment["safety_met"])
        self.assertFalse(assessment["release_eligible"])

    def test_unknown_secret_bearing_field_is_rejected(self) -> None:
        document = valid_document()
        document["password"] = "must never be accepted"
        with self.assertRaisesRegex(MODULE.ValidationError, "extra"):
            MODULE.validate_result(document)

    def test_unknown_candidate_memory_is_rejected(self) -> None:
        document = valid_document()
        document["profile"]["memory_kib"] = 32768
        with self.assertRaisesRegex(MODULE.ValidationError, "candidate grid"):
            MODULE.validate_result(document)


if __name__ == "__main__":
    unittest.main()

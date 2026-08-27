# SPDX-License-Identifier: MPL-2.0
from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


TOOLS = Path(__file__).parents[1] / "tools"
sys.path.insert(0, str(TOOLS))

from validate_results import (  # noqa: E402
    ATTACHMENT_PREFIX,
    RECORD_PREFIX,
    ValidationError,
    extract_pair,
    validate_attachment,
    validate_record,
)


def base(evidence_type: str) -> dict:
    return {
        "schema_version": 1,
        "evidence_type": evidence_type,
        "platform": "android",
        "physical_device": True,
        "build_revision": "abcdef0123456789",
        "build_mode": "release",
        "manufacturer": "Synthetic",
        "model": "Physical test phone",
        "os_version": "15",
        "abi": "arm64-v8a",
        "ram_mib": 2048,
        "memory_metric": "pss",
        "low_memory_after": False,
        "battery_percent": 80,
        "power_saver": False,
        "thermal": "none",
    }


def record_document() -> dict:
    return base("record") | {
        "record_count": 10_000,
        "stored_bytes": 2_000_000,
        "unique_nonce_count": 10_000,
        "ciphertext_sha256": "a" * 64,
        "write_ms": 1000.0,
        "unlock_ms": 500.0,
        "token_count": 30_000,
        "memory_before_mib": 30.0,
        "memory_after_unlock_mib": 70.0,
        "memory_delta_mib": 40.0,
        "plaintext_sentinel_on_disk": False,
        "corruption_rejected": True,
        "last_valid_index_preserved": True,
        "stale_session_rejected": True,
        "atomic_replacement_exercised": True,
        "nonce_counter_after": 10_001,
    }


def attachment_document(gib: int = 5) -> dict:
    total = gib * 1024**3
    chunks = total // 1024**2
    return base("attachment") | {
        "total_plaintext_bytes": total,
        "chunk_bytes": 1024**2,
        "chunk_count": chunks,
        "unique_nonce_count": chunks,
        "emitted_bytes": total + chunks * 32,
        "final_chunk_bytes": 1024**2,
        "manifest_sha256": "b" * 64,
        "elapsed_ms": 5000.0,
        "memory_before_mib": 30.0,
        "peak_memory_mib": 80.0,
        "memory_delta_mib": 50.0,
        "fault_paths": {
            "empty_stream_promoted": True,
            "short_final_chunk_bytes": 123,
            "cancellation_preserved_previous": True,
            "storage_full_preserved_previous": True,
            "corruption_rejected": True,
        },
        "nonce_counter_after": chunks + 5,
    }


class MobileStressValidationTests(unittest.TestCase):
    def test_valid_physical_pair_is_eligible(self) -> None:
        self.assertTrue(validate_record(record_document())["release_eligible"])
        self.assertTrue(validate_attachment(attachment_document())["release_eligible"])

    def test_valid_ios_physical_pair_is_eligible(self) -> None:
        record = record_document()
        attachment = attachment_document()
        for document in (record, attachment):
            document.update(
                platform="ios",
                manufacturer="Apple",
                model="iPhone15,4",
                os_version="18.6",
                abi="arm64",
                memory_metric="rss",
                thermal="nominal",
            )
        self.assertTrue(validate_record(record)["release_eligible"])
        self.assertTrue(validate_attachment(attachment)["release_eligible"])

    def test_unknown_platform_is_rejected(self) -> None:
        record = record_document()
        record["platform"] = "desktop"
        with self.assertRaisesRegex(ValidationError, "Android or iOS"):
            validate_record(record)

    def test_platform_memory_metric_mismatch_is_rejected(self) -> None:
        record = record_document()
        record["memory_metric"] = "rss"
        with self.assertRaisesRegex(ValidationError, "must be 'pss'"):
            validate_record(record)

    def test_emulator_pair_is_valid_but_not_eligible(self) -> None:
        record = record_document()
        attachment = attachment_document()
        record["physical_device"] = False
        attachment["physical_device"] = False
        self.assertFalse(validate_record(record)["release_eligible"])
        self.assertFalse(validate_attachment(attachment)["release_eligible"])

    def test_plaintext_or_nonce_failure_is_not_eligible(self) -> None:
        record = record_document()
        record["plaintext_sentinel_on_disk"] = True
        self.assertFalse(validate_record(record)["release_eligible"])
        nonce_failure = record_document()
        nonce_failure["unique_nonce_count"] = 9_999
        with self.assertRaisesRegex(ValidationError, "10,000"):
            validate_record(nonce_failure)

    def test_unexercised_atomic_replacement_is_not_eligible(self) -> None:
        record = record_document()
        record["atomic_replacement_exercised"] = False
        self.assertFalse(validate_record(record)["release_eligible"])

    def test_reset_nonce_counter_is_rejected(self) -> None:
        record = record_document()
        record["nonce_counter_after"] = 10_000
        with self.assertRaisesRegex(ValidationError, "prior generation"):
            validate_record(record)

        attachment = attachment_document()
        attachment["nonce_counter_after"] -= 1
        with self.assertRaisesRegex(ValidationError, "fault paths"):
            validate_attachment(attachment)

    def test_attachment_fault_or_memory_failure_is_not_eligible(self) -> None:
        attachment = attachment_document()
        attachment["fault_paths"]["corruption_rejected"] = False
        self.assertFalse(validate_attachment(attachment)["release_eligible"])
        high_memory = attachment_document()
        high_memory["memory_delta_mib"] = 300.0
        self.assertFalse(validate_attachment(high_memory)["release_eligible"])

    def test_unknown_secret_field_is_rejected(self) -> None:
        record = record_document()
        record["key"] = "must never be accepted"
        with self.assertRaisesRegex(ValidationError, "extra"):
            validate_record(record)

    def test_extracts_exactly_one_pair(self) -> None:
        record = record_document()
        attachment = attachment_document()
        log = (
            "I/TestRunner " + RECORD_PREFIX + json.dumps(record) + "\n"
            + "I/TestRunner " + ATTACHMENT_PREFIX + json.dumps(attachment) + "\n"
        )
        self.assertEqual((record, attachment), extract_pair(log))

    def test_duplicate_marker_is_rejected(self) -> None:
        record = record_document()
        attachment = attachment_document()
        record_line = RECORD_PREFIX + json.dumps(record)
        log = record_line + "\n" + record_line + "\n" + ATTACHMENT_PREFIX + json.dumps(attachment)
        with self.assertRaisesRegex(ValidationError, "exactly one"):
            extract_pair(log)


if __name__ == "__main__":
    unittest.main()

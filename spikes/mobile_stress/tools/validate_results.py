# SPDX-License-Identifier: MPL-2.0
"""Validate Android/iOS record-search and attachment-stream physical evidence."""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any


class ValidationError(ValueError):
    """Raised when diagnostic evidence is incomplete or unsafe."""


HEX_64 = re.compile(r"^[0-9a-fA-F]{64}$")
REVISION = re.compile(r"^[0-9a-fA-F]{7,64}$")
RECORD_PREFIX = "LOCALHOLD_RECORD_EVIDENCE "
ATTACHMENT_PREFIX = "LOCALHOLD_ATTACHMENT_EVIDENCE "
GIB = 1024**3
CHUNK_BYTES = 1024**2

BASE_KEYS = {
    "schema_version",
    "evidence_type",
    "platform",
    "physical_device",
    "build_revision",
    "build_mode",
    "manufacturer",
    "model",
    "os_version",
    "abi",
    "ram_mib",
    "memory_metric",
    "low_memory_after",
    "battery_percent",
    "power_saver",
    "thermal",
}
RECORD_KEYS = BASE_KEYS | {
    "record_count",
    "stored_bytes",
    "unique_nonce_count",
    "ciphertext_sha256",
    "write_ms",
    "unlock_ms",
    "token_count",
    "memory_before_mib",
    "memory_after_unlock_mib",
    "memory_delta_mib",
    "plaintext_sentinel_on_disk",
    "corruption_rejected",
    "last_valid_index_preserved",
    "stale_session_rejected",
    "atomic_replacement_exercised",
    "nonce_counter_after",
}
ATTACHMENT_KEYS = BASE_KEYS | {
    "total_plaintext_bytes",
    "chunk_bytes",
    "chunk_count",
    "unique_nonce_count",
    "emitted_bytes",
    "final_chunk_bytes",
    "manifest_sha256",
    "elapsed_ms",
    "memory_before_mib",
    "peak_memory_mib",
    "memory_delta_mib",
    "fault_paths",
    "nonce_counter_after",
}


def _exact_keys(document: dict[str, Any], expected: set[str]) -> None:
    missing = expected - set(document)
    extra = set(document) - expected
    if missing or extra:
        raise ValidationError(
            f"keys mismatch; missing={sorted(missing)}, extra={sorted(extra)}"
        )


def _boolean(value: Any, name: str) -> bool:
    if not isinstance(value, bool):
        raise ValidationError(f"{name} must be boolean")
    return value


def _integer(value: Any, name: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        raise ValidationError(f"{name} must be an integer in [{minimum}, {maximum}]")
    return value


def _number(value: Any, name: str, minimum: float = 0.0) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValidationError(f"{name} must be numeric")
    number = float(value)
    if not math.isfinite(number) or number < minimum:
        raise ValidationError(f"{name} must be finite and at least {minimum}")
    return number


def _text(value: Any, name: str, maximum: int = 128) -> str:
    if not isinstance(value, str) or not 1 <= len(value) <= maximum:
        raise ValidationError(f"{name} must be a non-empty string")
    return value


def _validate_base(document: dict[str, Any], expected_type: str) -> bool:
    if document["schema_version"] != 1 or document["evidence_type"] != expected_type:
        raise ValidationError("unexpected schema_version or evidence_type")
    if document["platform"] not in {"android", "ios"} or document["build_mode"] != "release":
        raise ValidationError("evidence must be an Android or iOS release build")
    if REVISION.fullmatch(_text(document["build_revision"], "build_revision", 64)) is None:
        raise ValidationError("build_revision is invalid")
    platform = document["platform"]
    expected_memory_metric = "pss" if platform == "android" else "rss"
    if document["memory_metric"] != expected_memory_metric:
        raise ValidationError(
            f"memory_metric must be {expected_memory_metric!r} for {platform}"
        )
    physical = _boolean(document["physical_device"], "physical_device")
    for key in ("manufacturer", "model", "os_version", "abi", "thermal"):
        _text(document[key], key)
    _integer(document["ram_mib"], "ram_mib", 512, 65536)
    _integer(document["battery_percent"], "battery_percent", 0, 100)
    low_memory = _boolean(document["low_memory_after"], "low_memory_after")
    _boolean(document["power_saver"], "power_saver")
    return physical and not low_memory


def validate_record(document: Any) -> dict[str, Any]:
    if not isinstance(document, dict):
        raise ValidationError("record evidence root must be an object")
    _exact_keys(document, RECORD_KEYS)
    base_eligible = _validate_base(document, "record")
    if document["record_count"] != 10_000 or document["unique_nonce_count"] != 10_000:
        raise ValidationError("record and nonce counts must both be 10,000")
    if _integer(document["nonce_counter_after"], "nonce_counter_after", 1, 2**63 - 1) != 10_001:
        raise ValidationError("record nonce counter must include the prior generation")
    _integer(document["stored_bytes"], "stored_bytes", 1, 2**31)
    if HEX_64.fullmatch(_text(document["ciphertext_sha256"], "ciphertext_sha256", 64)) is None:
        raise ValidationError("ciphertext_sha256 is invalid")
    _number(document["write_ms"], "write_ms", 0.000001)
    _number(document["unlock_ms"], "unlock_ms", 0.000001)
    _integer(document["token_count"], "token_count", 1, 1_000_000)
    _number(document["memory_before_mib"], "memory_before_mib")
    _number(document["memory_after_unlock_mib"], "memory_after_unlock_mib")
    memory_delta = _number(document["memory_delta_mib"], "memory_delta_mib")
    safe = (
        not _boolean(document["plaintext_sentinel_on_disk"], "plaintext_sentinel_on_disk")
        and _boolean(document["corruption_rejected"], "corruption_rejected")
        and _boolean(document["last_valid_index_preserved"], "last_valid_index_preserved")
        and _boolean(document["stale_session_rejected"], "stale_session_rejected")
        and _boolean(document["atomic_replacement_exercised"], "atomic_replacement_exercised")
        and memory_delta < 256.0
    )
    return {"valid": True, "release_eligible": base_eligible and safe, "safe": safe}


def validate_attachment(document: Any) -> dict[str, Any]:
    if not isinstance(document, dict):
        raise ValidationError("attachment evidence root must be an object")
    _exact_keys(document, ATTACHMENT_KEYS)
    base_eligible = _validate_base(document, "attachment")
    total = _integer(document["total_plaintext_bytes"], "total_plaintext_bytes", GIB, 5 * GIB)
    if total not in {GIB, 5 * GIB} or document["chunk_bytes"] != CHUNK_BYTES:
        raise ValidationError("attachment must be an exact 1 GiB or 5 GiB run")
    expected_chunks = math.ceil(total / CHUNK_BYTES)
    if document["chunk_count"] != expected_chunks:
        raise ValidationError("chunk_count does not match total size")
    if document["unique_nonce_count"] != expected_chunks:
        raise ValidationError("nonce count does not match chunk count")
    if (
        _integer(document["nonce_counter_after"], "nonce_counter_after", 1, 2**63 - 1)
        != expected_chunks + 5
    ):
        raise ValidationError("attachment nonce counter must include all fault paths")
    _integer(document["emitted_bytes"], "emitted_bytes", total + expected_chunks * 16, 6 * GIB)
    if document["final_chunk_bytes"] != CHUNK_BYTES:
        raise ValidationError("full-GiB run must end with a full chunk")
    if HEX_64.fullmatch(_text(document["manifest_sha256"], "manifest_sha256", 64)) is None:
        raise ValidationError("manifest_sha256 is invalid")
    _number(document["elapsed_ms"], "elapsed_ms", 0.000001)
    _number(document["memory_before_mib"], "memory_before_mib")
    _number(document["peak_memory_mib"], "peak_memory_mib")
    memory_delta = _number(document["memory_delta_mib"], "memory_delta_mib")
    faults = document["fault_paths"]
    expected_fault_keys = {
        "empty_stream_promoted",
        "short_final_chunk_bytes",
        "cancellation_preserved_previous",
        "storage_full_preserved_previous",
        "corruption_rejected",
    }
    if not isinstance(faults, dict):
        raise ValidationError("fault_paths must be an object")
    _exact_keys(faults, expected_fault_keys)
    safe_faults = (
        faults["empty_stream_promoted"] is True
        and faults["short_final_chunk_bytes"] == 123
        and faults["cancellation_preserved_previous"] is True
        and faults["storage_full_preserved_previous"] is True
        and faults["corruption_rejected"] is True
    )
    safe = safe_faults and memory_delta < 256.0
    return {
        "valid": True,
        "release_eligible": base_eligible and safe,
        "safe": safe,
        "gib": total // GIB,
    }


def extract_pair(log_text: str) -> tuple[dict[str, Any], dict[str, Any]]:
    found: dict[str, list[dict[str, Any]]] = {
        RECORD_PREFIX: [],
        ATTACHMENT_PREFIX: [],
    }
    for line in log_text.splitlines():
        for prefix in found:
            marker = line.find(prefix)
            if marker < 0:
                continue
            try:
                value = json.loads(line[marker + len(prefix):].strip())
            except json.JSONDecodeError as error:
                raise ValidationError(f"malformed JSON after {prefix.strip()}") from error
            if not isinstance(value, dict):
                raise ValidationError("evidence marker must contain an object")
            found[prefix].append(value)
    if len(found[RECORD_PREFIX]) != 1 or len(found[ATTACHMENT_PREFIX]) != 1:
        raise ValidationError("expected exactly one record and one attachment marker")
    record = found[RECORD_PREFIX][0]
    attachment = found[ATTACHMENT_PREFIX][0]
    validate_record(record)
    validate_attachment(attachment)
    return record, attachment


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logcat", type=Path)
    parser.add_argument("record_output", type=Path)
    parser.add_argument("attachment_output", type=Path)
    args = parser.parse_args()
    try:
        record, attachment = extract_pair(args.logcat.read_text(encoding="utf-8"))
        record_assessment = validate_record(record)
        attachment_assessment = validate_attachment(attachment)
    except (OSError, ValidationError) as error:
        print(json.dumps({"valid": False, "error": str(error)}, ensure_ascii=False))
        return 1
    args.record_output.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.attachment_output.write_text(
        json.dumps(attachment, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"record": record_assessment, "attachment": attachment_assessment}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

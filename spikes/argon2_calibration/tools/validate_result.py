# SPDX-License-Identifier: MPL-2.0
"""Validate Localhold Argon2id calibration evidence without crypto code."""

from __future__ import annotations

import argparse
import json
import math
import re
import statistics
from datetime import datetime
from pathlib import Path
from typing import Any


class ValidationError(ValueError):
    """Raised when benchmark evidence is malformed or incomplete."""


HEX_RE = re.compile(r"^[0-9a-fA-F]+$")
CANDIDATE_MEMORY_KIB = {65536, 98304, 131072}
CANDIDATE_OPERATIONS = {2, 3, 4}


def _require_keys(value: dict[str, Any], expected: set[str], optional: set[str] | None = None) -> None:
    actual = set(value)
    missing = expected - actual
    extra = actual - expected - (optional or set())
    if missing or extra:
        raise ValidationError(f"keys mismatch; missing={sorted(missing)}, extra={sorted(extra)}")


def _bounded_string(value: Any, name: str, maximum: int = 128) -> str:
    if not isinstance(value, str) or not 1 <= len(value) <= maximum:
        raise ValidationError(f"{name} must be a non-empty string up to {maximum} characters")
    return value


def _boolean(value: Any, name: str) -> bool:
    if not isinstance(value, bool):
        raise ValidationError(f"{name} must be boolean")
    return value


def _integer(value: Any, name: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        raise ValidationError(f"{name} must be an integer in [{minimum}, {maximum}]")
    return value


def _hex(value: Any, name: str, length: int) -> str:
    text = _bounded_string(value, name, length)
    if len(text) != length or HEX_RE.fullmatch(text) is None:
        raise ValidationError(f"{name} must be exactly {length} hexadecimal characters")
    return text.lower()


def nearest_rank_percentile(samples: list[float], percentile: float) -> float:
    ordered = sorted(samples)
    return ordered[math.ceil(percentile * len(ordered)) - 1]


def validate_result(document: Any) -> dict[str, Any]:
    if not isinstance(document, dict):
        raise ValidationError("root must be an object")
    _require_keys(document, {
        "schema_version", "run_id", "recorded_at", "platform", "physical_device",
        "device", "build", "library", "profile", "timing", "safety", "vector",
    })
    if document["schema_version"] != 1:
        raise ValidationError("schema_version must be 1")
    _bounded_string(document["run_id"], "run_id")
    recorded_at = _bounded_string(document["recorded_at"], "recorded_at")
    try:
        parsed_at = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValidationError("recorded_at must be an ISO 8601 date-time") from error
    if parsed_at.tzinfo is None:
        raise ValidationError("recorded_at must include a UTC offset")
    if document["platform"] not in {"android", "ios"}:
        raise ValidationError("platform must be android or ios")
    physical_device = _boolean(document["physical_device"], "physical_device")

    device = document["device"]
    if not isinstance(device, dict):
        raise ValidationError("device must be an object")
    _require_keys(device, {"manufacturer", "model", "os_version", "abi", "ram_mib"})
    for key in ("manufacturer", "model", "os_version", "abi"):
        _bounded_string(device[key], f"device.{key}")
    _integer(device["ram_mib"], "device.ram_mib", 512, 65536)

    build = document["build"]
    if not isinstance(build, dict):
        raise ValidationError("build must be an object")
    _require_keys(build, {"revision", "mode"})
    revision = _bounded_string(build["revision"], "build.revision", 64)
    if not 7 <= len(revision) <= 64 or HEX_RE.fullmatch(revision) is None:
        raise ValidationError("build.revision must be 7-64 hexadecimal characters")
    if build["mode"] != "release":
        raise ValidationError("build.mode must be release")

    library = document["library"]
    if not isinstance(library, dict):
        raise ValidationError("library must be an object")
    _require_keys(library, {"name", "version", "source_sha256"})
    if library["name"] != "libsodium":
        raise ValidationError("library.name must be libsodium")
    _bounded_string(library["version"], "library.version", 64)
    _hex(library["source_sha256"], "library.source_sha256", 64)

    profile = document["profile"]
    if not isinstance(profile, dict):
        raise ValidationError("profile must be an object")
    _require_keys(profile, {"algorithm", "version", "memory_kib", "operations", "parallelism", "salt_bytes", "output_bytes"})
    if profile["algorithm"] != "argon2id" or profile["version"] != 19:
        raise ValidationError("profile must use Argon2id version 1.3 (19)")
    if profile["memory_kib"] not in CANDIDATE_MEMORY_KIB:
        raise ValidationError("profile.memory_kib is outside the approved candidate grid")
    if profile["operations"] not in CANDIDATE_OPERATIONS:
        raise ValidationError("profile.operations is outside the approved candidate grid")
    if profile["parallelism"] != 1 or profile["salt_bytes"] != 16 or profile["output_bytes"] != 32:
        raise ValidationError("profile lane, salt or output size differs from ADR-0020")

    timing = document["timing"]
    if not isinstance(timing, dict):
        raise ValidationError("timing must be an object")
    _require_keys(timing, {"warmup_count", "samples_ms", "stress_successful_runs"})
    _integer(timing["warmup_count"], "timing.warmup_count", 5, 1000)
    _integer(timing["stress_successful_runs"], "timing.stress_successful_runs", 0, 20)
    raw_samples = timing["samples_ms"]
    if not isinstance(raw_samples, list) or len(raw_samples) < 30:
        raise ValidationError("timing.samples_ms must contain at least 30 samples")
    samples: list[float] = []
    for index, value in enumerate(raw_samples):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValidationError(f"timing.samples_ms[{index}] must be numeric")
        sample = float(value)
        if not math.isfinite(sample) or not 0 < sample <= 60000:
            raise ValidationError(f"timing.samples_ms[{index}] is outside (0, 60000]")
        samples.append(sample)

    safety = document["safety"]
    if not isinstance(safety, dict):
        raise ValidationError("safety must be an object")
    _require_keys(safety, {"oom", "crash", "anr", "safe_memory_pressure", "battery_percent", "power_saver", "thermal_before", "thermal_after"}, {"peak_rss_delta_mib"})
    for key in ("oom", "crash", "anr", "safe_memory_pressure", "power_saver"):
        _boolean(safety[key], f"safety.{key}")
    _integer(safety["battery_percent"], "safety.battery_percent", 0, 100)
    _bounded_string(safety["thermal_before"], "safety.thermal_before", 64)
    _bounded_string(safety["thermal_after"], "safety.thermal_after", 64)
    peak_rss = safety.get("peak_rss_delta_mib")
    if peak_rss is not None and (isinstance(peak_rss, bool) or not isinstance(peak_rss, (int, float)) or not math.isfinite(float(peak_rss)) or peak_rss < 0):
        raise ValidationError("safety.peak_rss_delta_mib must be null or a finite non-negative number")

    vector = document["vector"]
    if not isinstance(vector, dict):
        raise ValidationError("vector must be an object")
    _require_keys(vector, {"id", "output_sha256"})
    _bounded_string(vector["id"], "vector.id")
    _hex(vector["output_sha256"], "vector.output_sha256", 64)

    median_ms = statistics.median(samples)
    p95_ms = nearest_rank_percentile(samples, 0.95)
    floor_met = profile["memory_kib"] >= 65536 and profile["operations"] >= 3
    safety_met = (
        not safety["oom"] and not safety["crash"] and not safety["anr"]
        and safety["safe_memory_pressure"] and timing["stress_successful_runs"] == 20
    )
    eligible = physical_device and floor_met and 400 <= median_ms <= 1000 and p95_ms <= 1500 and safety_met
    return {
        "valid": True,
        "release_eligible": eligible,
        "median_ms": median_ms,
        "p95_ms": p95_ms,
        "sample_count": len(samples),
        "floor_met": floor_met,
        "safety_met": safety_met,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result", type=Path)
    args = parser.parse_args()
    try:
        document = json.loads(args.result.read_text(encoding="utf-8"))
        assessment = validate_result(document)
    except (OSError, json.JSONDecodeError, ValidationError) as error:
        print(json.dumps({"valid": False, "error": str(error)}, ensure_ascii=False))
        return 1
    print(json.dumps(assessment, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# SPDX-License-Identifier: MPL-2.0
"""Extract and validate one Localhold Argon2 evidence document from Android logcat."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from validate_result import ValidationError, validate_result


PREFIX = "LOCALHOLD_ARGON2_EVIDENCE "


def extract_document(log_text: str) -> dict[str, object]:
    candidates: list[dict[str, object]] = []
    for line in log_text.splitlines():
        marker_index = line.find(PREFIX)
        if marker_index < 0:
            continue
        payload = line[marker_index + len(PREFIX):].strip()
        try:
            decoded = json.loads(payload)
        except json.JSONDecodeError as error:
            raise ValidationError("evidence marker contains malformed JSON") from error
        if not isinstance(decoded, dict):
            raise ValidationError("evidence marker must contain a JSON object")
        candidates.append(decoded)
    if len(candidates) != 1:
        raise ValidationError(f"expected exactly one evidence marker, found {len(candidates)}")
    validate_result(candidates[0])
    return candidates[0]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logcat", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        document = extract_document(args.logcat.read_text(encoding="utf-8"))
    except (OSError, ValidationError) as error:
        print(json.dumps({"valid": False, "error": str(error)}, ensure_ascii=False))
        return 1
    args.output.write_text(
        json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(validate_result(document), ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

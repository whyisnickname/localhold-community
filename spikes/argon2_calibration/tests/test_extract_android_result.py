# SPDX-License-Identifier: MPL-2.0
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


TOOLS = Path(__file__).parents[1] / "tools"
sys.path.insert(0, str(TOOLS))

from extract_android_result import PREFIX, extract_document  # noqa: E402
from test_validate_result import valid_document  # noqa: E402
from validate_result import ValidationError  # noqa: E402


class AndroidResultExtractionTests(unittest.TestCase):
    def test_extracts_exactly_one_valid_document(self) -> None:
        document = valid_document()
        log = f"08-22 I/TestRunner: {PREFIX}{json.dumps(document)}\n"
        self.assertEqual(document, extract_document(log))

    def test_rejects_duplicate_evidence_markers(self) -> None:
        document = valid_document()
        line = f"I/TestRunner: {PREFIX}{json.dumps(document)}"
        with self.assertRaisesRegex(ValidationError, "exactly one"):
            extract_document(f"{line}\n{line}\n")

    def test_rejects_malformed_marker(self) -> None:
        with self.assertRaisesRegex(ValidationError, "malformed JSON"):
            extract_document(f"{PREFIX}{{not-json}}")


if __name__ == "__main__":
    unittest.main()

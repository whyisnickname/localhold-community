# Localhold Argon2id calibration evidence tools

SPDX-License-Identifier: MPL-2.0

This directory does **not** implement Argon2id. It validates benchmark evidence
produced by the pinned native implementation described in ADR-0020.

Run:

```powershell
python -m unittest discover community/spikes/argon2_calibration/tests
python community/spikes/argon2_calibration/tools/validate_result.py result.json
```

The validator reports whether a document is structurally valid and whether that
single device/profile result is eligible for the release gate. Release selection
still requires matching eligible reports and vectors from physical Android and
iOS devices. A simulator or desktop result is diagnostic only.

Acceptance criteria:

- malformed, incomplete or non-finite timing data is rejected;
- empty/oversized password, bad salt and out-of-grid memory/operations/sample
  inputs fail closed, while a wrong password derives a distinct candidate rather
  than being misreported as a KDF failure;
- weak/unapproved profiles and non-physical runs may be recorded but cannot be
  reported as release-eligible;
- median and nearest-rank p95 are calculated from raw samples, not trusted from
  caller-provided summaries;
- OOM, crash, ANR, memory-pressure or incomplete stress evidence fails eligibility;
- result documents contain vector identifiers/hashes, never passwords or raw KEKs.

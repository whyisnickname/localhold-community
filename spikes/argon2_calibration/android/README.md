# Android Argon2id calibration harness

SPDX-License-Identifier: MPL-2.0

This Android-only module is a Stage 2 benchmark harness, not production vault
code. It accepts synthetic byte vectors, derives a temporary 32-byte value with
the explicit libsodium Argon2id 1.3 API, hashes that temporary output for
cross-platform comparison and returns timing samples. It never returns the raw
derived bytes and contains no logging API.

Before building, place the independently verified upstream artifact at:

`libs/libsodium-1.0.21.0.aar`

The AAR must be built from the pinned source in ADR-0020 with upstream
`dist-build/android-aar.sh`. Do not download a third-party Maven wrapper.

The module intentionally has no Gradle wrapper checked in. Use the repository's
pinned Android/Gradle environment or add a reviewed wrapper in the engineering
foundation stage.

Run source-boundary tests on any host:

```powershell
python -m unittest discover community/spikes/argon2_calibration/tests
```

Physical device execution and evidence export are still required. Emulator runs
must be marked diagnostic and cannot close ADR-0020.

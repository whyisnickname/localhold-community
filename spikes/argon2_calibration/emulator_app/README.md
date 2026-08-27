<!-- SPDX-License-Identifier: MPL-2.0 -->
# Android multi-ABI diagnostic harness

This app runs the pinned libsodium Argon2id JNI harness on an API 24 x86_64
emulator or an ARM64 physical device exposed through ADB. Emulator output remains
diagnostic and cannot close the physical ARM performance gate in ADR-0020.

Builds require `LOCALHOLD_LIBSODIUM_X86_ROOT` and
`LOCALHOLD_LIBSODIUM_ARM64_ROOT` pointing to independently verified minimal
Android builds of libsodium 1.0.21. The library is not downloaded by Gradle and
no third-party Maven crypto wrapper is used. The x86_64 ABI is diagnostic; the
arm64-v8a ABI is used by the physical-device farm.

The `release` diagnostic variant is release-optimized but debug-signed only so
a diagnostic device can install it. It must never be published. The physical run
is restricted to the schema-producing test by
`tool/run_physical_adb.ps1`; the candidate-grid smoke test is for
diagnostic emulator runs.

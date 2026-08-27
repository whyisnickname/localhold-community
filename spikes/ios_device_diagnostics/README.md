# Selectel iOS physical-device diagnostics

SPDX-License-Identifier: MPL-2.0

This release-only application packages the existing Stage 2 Argon2id and
mobile-stress evidence collectors for a real iPhone that is re-signed by
Selectel Mobile Farm. It is not the Localhold product, has no backend or
production vault path, and accepts no user secrets.

Acceptance criteria are defined in ADR-0035 before implementation. In short:

- build an arm64 `iphoneos` IPA with minimum iOS 15.0 from the pinned verified
  libsodium source;
- require an explicit tap before running and use synthetic fixtures only;
- emit the nine approved Argon2id candidates plus exact 1 GiB and 5 GiB
  record/attachment evidence to the visible UI and unified device log;
- contain no network API, account, analytics, payment, extension, provisioning
  profile, App Group or Associated Domain;
- publish only the unsigned IPA, its SHA-256 and non-secret build metadata to
  the private workflow artifact;
- treat Selectel re-signing and iPhone X/iOS 16.7.10 as diagnostic evidence,
  never as production signing, TestFlight or entitlement evidence.

The device is rented only after the private CI artifact and hash pass. Android
and iPhone rental windows are sequential.

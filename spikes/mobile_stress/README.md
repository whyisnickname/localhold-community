# Android/iOS mobile storage stress spike

SPDX-License-Identifier: MPL-2.0

The release-instrumentation Android application and CryptoKit iOS harness supply
the mobile evidence boundaries for ADR-0023 and ADR-0024. They contain no
production vault data, account SDK, network permission, analytics or backend
dependency.

Acceptance criteria defined before implementation:

- persist 10,000 independently authenticated synthetic record blobs with only
  technical IDs visible and mechanically prove a plaintext sentinel is absent
  from the stored bytes;
- atomically replace a previously published valid record generation and prove
  that no temporary sibling remains after the replacement;
- consume record and attachment nonces from separate native allocator domains
  and distinct synthetic keys across replacements and injected faults, with no
  per-operation epoch reset;
- build search tokens only after authenticated unlock, return the expected
  record, preserve the last complete index after a corrupt blob, and invalidate
  stale session handles on lock;
- stream synthetic 1 GiB and 5 GiB attachments through independently
  authenticated 1 MiB chunks with unique nonces and bounded memory;
- cover empty and final-short chunks, cancellation, simulated storage-full and
  tag corruption without promoting an incomplete replacement;
- emit only schema-shaped timings, memory observations, hashes and synthetic
  identifiers from a release-optimized physical-device run;
- keep all APKs debug-signed for diagnostic physical-device installation only and never publish
  them.

Physical Android and iPhone results remain mandatory. A build, host verifier or
simulator run alone does not accept ADR-0023/0024.

<!-- SPDX-License-Identifier: MPL-2.0 -->
# `.localhold` Stage 2 container spike

## Acceptance criteria before implementation

- Node, Kotlin and Swift emit the same canonical bytes for the 0-byte, 19-byte
  and 4097-byte synthetic chunks.
- Manifest bytes are canonical UTF-8 JSON with an exact field allowlist.
- Every payload chunk has a unique canonical ID and exact declared plaintext and
  ciphertext sizes; counts and sizes are checked before allocation/decryption.
- Unknown versions/fields, duplicate IDs or JSON keys, overflow lengths,
  truncation, trailing bytes, nonce mismatch, tag failure and any compression
  declaration fail closed.
- No decoded result is returned until every chunk and the aggregate digest have
  authenticated. Production restore must additionally stage into a new vault and
  atomically commit as required by ADR-0025.
- Large-file OOM feasibility is evidenced by the separate streaming attachment
  spike; this in-memory canonical-vector harness must not be mistaken for a
  production 1–5 GiB reader.

The fixed key and deterministic nonces are synthetic interoperability fixtures
only. Production backup keys and nonce epochs follow ADR-0020/0021/0024.

Public format identifiers fixed by ADR-0025 are the `.localhold` extension,
eight-byte ASCII magic `LOCALH1\n` and AAD prefix `localhold-backup-v1`.

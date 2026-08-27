# Native nonce-allocation protocol spike

SPDX-License-Identifier: MPL-2.0

This spike supplies the missing ADR-0021 allocation evidence. It models the
small native state transition that must run inside one durable, serialized vault
transaction; it does not claim that an in-memory test store is a production
database.

Acceptance criteria defined before implementation:

- a nonce is exactly a four-byte epoch followed by an unsigned 64-bit
  big-endian counter;
- concurrent reservations through one atomic store never return duplicates;
- failure before commit returns no nonce and leaves the counter reusable;
- failure after commit but before return loses one nonce safely and the next
  reservation cannot reuse it;
- unsigned counter exhaustion fails closed without wrapping;
- missing state cannot reserve or silently invent an epoch; explicit
  new-key initialization succeeds once and repeated initialization fails;
- restore or writable clone is rejected under the previous key-generation ID
  and rotates the DEK identity plus nonce epoch before the first write;
- Kotlin and Swift verify the same deterministic layout vectors;
- the protocol has no network, logging, key or caller-controlled nonce API.

Production integration in Stage 4 must bind this transition to the same durable
transaction that reserves the encrypted write. A database/OS rollback that
restores both ciphertext and nonce state remains a restore event and must rotate
the DEK/key-generation identity before any new write. A new random 32-bit epoch
without a new DEK is not sufficient.

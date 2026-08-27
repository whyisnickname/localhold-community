<!-- SPDX-License-Identifier: MPL-2.0 -->
# Third-party notices

## BIP-39 English word list

- Upstream: `bitcoin/bips`, `bip-0039/english.txt`
- Pinned revision: `7fe0b034ec967b52a5a28276419117326df93263`
- Canonical upstream SHA-256 (LF bytes, final newline):
  `2F5EED53A4727B4BF8880D8F3F199EFC90E58503646D9FF8EFF3A2ED3B24DBDA`
- License: MIT, inherited from BIP-39 and its auxiliary English word list.
- Use in Localhold: only the entropy/checksum/word-index representation. The
  wallet PBKDF, wallet seed derivation and cryptocurrency paths are not used.

The two packaged copies are intentionally byte-identical. A release check must
verify the checksum, 2048 unique sorted lowercase ASCII words and identical
Android/iOS bytes before either asset is published.

## libsodium 1.0.21

- Upstream: `jedisct1/libsodium`, release `1.0.21-RELEASE`
- Pinned source revision: `d24faf56214469b354b01c8ba36257e04737101e`
- Source archive SHA-256:
  `9E4285C7A419E82DEDB0BE63A72EEA357D6943BC3E28E6735BF600DD4883FEAF`
- License: ISC
- Use in Localhold: the explicit `crypto_pwhash_ALG_ARGON2ID13` C API for the
  native master-password KDF; no network or telemetry capability.

Android binaries are reproducibly built from the pinned, signature-verified
source. The iOS XCFramework is rebuilt from that source in private macOS CI.
The upstream license is packaged at
`android/src/main/third_party/libsodium/LICENSE`.

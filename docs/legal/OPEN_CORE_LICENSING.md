# Localhold open-core licensing boundary

- Status: mandatory architecture and release standard
- Date: 2026-08-22
- Community license: Mozilla Public License 2.0 (`MPL-2.0`)
- Public attribution: `whyisnickname`, the pseudonym of the individual project owner
- Legal identity: retained privately and not required in the public repository

## 1. What “Free is open source” means

Localhold will publish source sufficient to build and inspect an independent Android/iOS client that provides the advertised Free local functionality without a Localhold account or backend.

It is not enough to publish interfaces, screenshots or a non-buildable snapshot. The community source must include:

- local vault creation, lock/unlock and encrypted persistence;
- master-password, recovery and optional biometric platform adapters used by Free;
- built-in record types and standard fields;
- local CRUD, folders, tags, favorites, archive and trash;
- local display-safe search, sorting and filters;
- basic password generator;
- basic system autofill needed by Free;
- supported portability import and manual portability export;
- Privacy Center information applicable to the community build;
- RU/EN resources, accessibility behavior, tests and build instructions required for those features.

The published source does not need to include Premium-only capability implementations merely to display compatible portable data created earlier. Existing Premium-created values must remain readable/editable/exportable in the commercial app after expiry as required by the entitlement policy.

## 2. Proprietary scope

The following remain proprietary unless a later ADR changes their license:

- Premium feature implementations and commercial-only UI;
- account, authentication, Trial, entitlement and billing client modules;
- Django backend and administrative tooling;
- payment-provider adapters and private anti-abuse logic;
- production infrastructure, secrets, signing keys and release credentials;
- official store listing assets and unreleased brand artwork;
- internal incident details and unreleased vulnerability information.

Security algorithms, file formats and network behavior are not kept secret as a security control. Public specifications and whitepapers may document proprietary components without licensing their implementation.

## 3. Planned repository boundary

The private working monorepo uses these logical zones:

```text
community/
  apps/mobile_free/          independently buildable Free Flutter client
  packages/vault_core/       local domain model, encrypted storage orchestration
  packages/free_features/    records, search, generator, import/export
  packages/native_security/  reviewed Android/iOS security adapters
  tests/                     unit, integration, golden and fault tests

apps/mobile/                 proprietary commercial composition and Premium UI
packages/premium_*/          proprietary Premium modules
services/backend/            proprietary Django service
infra/                       private deployment/release configuration
```

The final names may change during Stage 3, but the build and licensing properties may not.

The public mirror contains `community/`, the exact MPL-2.0 text, notices, dependency manifests, public build instructions, contribution/security policies and only explicitly approved documentation. It must not contain proprietary history, secrets or generated signing artifacts.

## 4. File and dependency rules

- Every Localhold-authored community source file uses
  `SPDX-License-Identifier: MPL-2.0`. Unmodified third-party source retains its
  upstream license and is allowed only through an explicit narrow path in
  `license-boundary.json` plus a matching `THIRD_PARTY_NOTICES.md` entry.
- Every proprietary source file uses the project-approved proprietary notice or an SPDX reference to the repository's proprietary license identifier.
- A source file cannot contain both community and proprietary implementation.
- Changes to an MPL-covered file stay MPL-covered in distributed source.
- Proprietary modules may call stable community interfaces from separate files/packages.
- Community packages must not depend on proprietary packages, backend availability, commercial feature flags or private artifact registries.
- Proprietary packages may depend on pinned community versions.
- Third-party licenses are allowlisted by use context; reciprocal/network-copyleft or source-availability obligations require explicit review.
- Generated code records its source template and license; generation cannot launder code across the boundary.
- Build scripts and dependency metadata necessary to compile the community client are included in the public mirror.

## 5. Public/commercial build behavior

### Community build

- no Localhold backend endpoints;
- no registration, Trial, payment or entitlement SDK;
- no advertising, analytics or tracking SDK;
- no nonfunctional Premium buttons that require proprietary code;
- all advertised Free behavior works offline;
- user may build and sign it under their own application identity;
- official Localhold signing keys and store identity are never published.

### Commercial build

- combines the same reviewed MPL community revision with separate proprietary modules;
- can show contextual Premium entry points and account/payment flows;
- preserves all Free behavior when backend access is unavailable;
- identifies the matching community source revision and provides required license notices;
- does not imply that proprietary modules are open source.

## 6. Trademark and fork communication

MPL-2.0 licenses copyright and applicable patent claims described by the license; it does not grant a general right to Localhold trademarks. Forks must not imply official status, use official signing keys or misrepresent their privacy/security review.

Before public release, create a separate trademark policy that permits accurate nominative references and legally required attribution while reserving official brand/store identity to the owner. Do not use the ® symbol or claim registration before evidence exists.

## 7. Contributions

External pull requests remain disabled until `CONTRIBUTING.md`, provenance checks and the contribution-rights model are published. Public issue reports and private vulnerability reports may be accepted earlier.

Before accepting code:

- verify contributor identity/provenance to the chosen reasonable level;
- require an explicit developer certificate or contribution agreement selected in a later legal decision;
- reject copied code, unclear AI-generated provenance and incompatible licenses;
- require tests, security review and MPL SPDX notices;
- document whether the owner retains practical ability to relicense or only to use contributions under MPL.

No contribution policy may silently transfer ownership or promise rights the contributor does not have.

## 8. Release obligations

For each commercial or community release:

1. record the exact community commit/tag and dependency lockfiles;
2. publish or retain the corresponding MPL source in a stable location;
3. ship the MPL notice and a clear source-location link in-app and with the executable;
4. run SPDX, dependency-license, secret and proprietary-leak scans;
5. verify the clean public mirror builds without private credentials or packages;
6. generate an SBOM for both community and commercial builds;
7. preserve source, notices, build evidence and released binaries for the required period;
8. recheck current app-store terms and third-party licenses;
9. verify public claims say **Free client is open source**, not **the whole service is open source**.

## 9. Acceptance tests and release blockers

Release is blocked if:

- the public Free client does not build from a clean documented checkout;
- any advertised Free action calls a proprietary module or Localhold backend;
- community source contains a secret, signing artifact, private endpoint credential or proprietary file;
- distributed MPL-covered executable code lacks timely source access and notices;
- a modified MPL file is withheld from the matching source release;
- the commercial app uses a different unrecorded community revision;
- dependency-license scanning has unresolved incompatible or unknown entries;
- store EULA/DRM terms are not reviewed for compatibility with the actual distribution;
- official marketing overstates the open-source scope;
- public attribution or the trademark-policy issuer is missing, contains a
  placeholder or conflicts with the private ownership record.

Required automated evidence:

- community dependency graph has zero proprietary nodes;
- public mirror allowlist and private-path denylist tests pass;
- secret and high-entropy scans pass;
- SPDX headers cover all distributed source files;
- clean Android build passes and iOS build passes in an appropriate macOS environment;
- Free offline E2E matrix passes in both community and commercial variants;
- community API/behavior compatibility tests pass against the commercial composition;
- source revision and source URL appear in generated About/legal notices.

## 10. Plain-language public explanation

> The Free part of Localhold is open source under MPL-2.0. You can inspect, build and modify the published Free client. Changes to its MPL-covered files must remain available under that license when distributed. Premium features, our account/payment backend, official signing keys and the Localhold brand are not included. Open source improves transparency, but it is not the same as an independent security audit.

The final user-facing legal notice must have a section-aligned plain-language version under the project's legal-document standard whenever it creates binding terms for users or contributors.

## 11. Sources

- MPL-2.0: <https://www.mozilla.org/en-US/MPL/2.0/>
- Mozilla MPL FAQ: <https://www.mozilla.org/en-US/MPL/2.0/FAQ/>
- OSI MPL-2.0 record: <https://opensource.org/license/MPL-2.0>

<!-- SPDX-License-Identifier: MPL-2.0 -->
# Localhold Community

This directory is the independently buildable Free-client and public-source
boundary under Mozilla Public License 2.0. The complete unmodified license text
is in [`LICENSE`](LICENSE).

Current foundation:

- `apps/mobile_free/` — standalone Android/iOS Flutter client;
- `packages/app_foundation/` — shared source identity and approved themes;
- `spikes/` — Stage 2 cryptography/platform evidence retained as MPL source.

Premium, account, entitlement, payment, backend, infrastructure, secrets and
official signing material are prohibited here. Community code may not import
anything from the proprietary repository roots. The public mirror strips the
`community/` prefix and is generated only from Git-tracked bytes at an exact
revision.

The authoritative boundary is documented in
`docs/legal/OPEN_CORE_LICENSING.md`, ADR-0015 and ADR-0037. These files are
included at those paths in the generated public mirror. The Free client being
open source is not a claim that the complete commercial product is open source
or independently audited.

## Build and verification

The public mirror records its exact private source revision and file hashes in
`PUBLIC_SOURCE_MANIFEST.json`. Verify a checkout before building:

```text
python tool/verify_public_tree.py .
```

CI uses the exact Flutter revision recorded in `.github/workflows/community-ci.yml`
and performs Dart tests, Android builds and unsigned iOS/Xcode builds. The
public workflow contains no production signing material or Localhold service
credential.

External code contributions are not accepted yet. See `CONTRIBUTING.md` and
use the private route in `SECURITY.md` for suspected vulnerabilities. Brand use
is covered by the paired legal and plain-language trademark policies.

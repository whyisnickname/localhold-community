# Autofill extension boundary spike

SPDX-License-Identifier: MPL-2.0

The Android app compiles a system-bound `AutofillService` that extracts package
and signing-certificate evidence before any possible vault query. It never logs
or persists the form and returns no dataset in this boundary spike.

The iOS source is an `ASCredentialProviderViewController` fail-closed skeleton
using the same exact app/web origin semantics. It requires an Xcode Credential
Provider Extension target and the AutoFill Credential Provider entitlement
before it can be compiled or run.

Neither extension uses Accessibility Service, screen scraping or network access.

Native acceptance criteria:

- app identity requires exact application/bundle ID and a 32-byte SHA-256 signer
  or exact Apple Team ID;
- web identity requires an already ASCII/IDNA-normalized exact host and exact
  port, with HTTPS defaulting to 443;
- substring, sibling/subdomain, public-suffix lookalike, malformed label,
  Unicode-homograph, wrong signer/team and wrong-port fixtures fail closed;
- a locked extension returns no broad or unfiltered credential fallback.
- Android signer extraction runs on every supported API: API 28+ uses
  `SigningInfo` and API 26–27 uses the legacy read-only signature list; a
  removed/unknown package fails to an empty signer set instead of crashing.

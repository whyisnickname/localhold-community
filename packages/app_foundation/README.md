<!-- SPDX-License-Identifier: MPL-2.0 -->
# Localhold application foundation

Shared MPL-2.0 visual tokens and build/source identity used by the independent
Free app and the proprietary commercial composition. It contains no backend,
account, Trial, entitlement, payment or tracking implementation.

The package owns the reviewed RU/EN localization baseline, responsive window
classes, Light/Dark/high-contrast adaptations, density and reduced-motion
contracts, minimum accessibility metrics and a closed presentation-safe async
state. Feature widgets depend on these contracts rather than hardcoded visual
values or provider exception messages.

This is an internal monorepo package rather than a published pub.dev library,
so its resolved lockfile is intentionally committed for clean-checkout
reproducibility.

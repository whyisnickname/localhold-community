<!-- SPDX-License-Identifier: MPL-2.0 -->
# Localhold vault native

Typed Flutter ↔ Kotlin/Swift production security boundary. Raw DEK/KEK values
never leave native code. The package uses exact-pinned Pigeon bindings and
closed, secret-free errors.

The same reviewed Pigeon host API also carries Stage 5 platform features:
notification permission, wall-clock/DST resolution, synthetic local reminder
requests, the fixed Add/Search/Lock launcher actions, and bounded chunked
inbound-share staging. These messages cannot represent a vault name, record or
field identifier, secret value, arbitrary shortcut, filename, source URI, or
network destination.

The Stage 2 spike remains separately under `community/spikes/key_bridge`.
Production registration is allowed only with reviewed native cryptography;
there is no fake cipher or Dart fallback.

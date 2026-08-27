<!-- SPDX-License-Identifier: MPL-2.0 -->
# Localhold vault native

Typed Flutter ↔ Kotlin/Swift production security boundary. Raw DEK/KEK values
never leave native code. The package uses exact-pinned Pigeon bindings and
closed, secret-free errors.

The Stage 2 spike remains separately under `community/spikes/key_bridge`.
Production registration is allowed only with reviewed native cryptography;
there is no fake cipher or Dart fallback.

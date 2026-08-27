<!-- SPDX-License-Identifier: MPL-2.0 -->

# Localhold key bridge spike

This MPL-2.0 package prototypes the typed Flutter ↔ Kotlin/Swift boundary from
ADR-0019. It does **not** implement cryptography and is not production-ready.

The contract deliberately never returns raw DEK/KEK values. Native spike adapters
return only `notImplemented`; Dart tests use an in-memory lifecycle fake that is
not part of the plugin registration path.

## Generate bindings

From this directory, with Flutter 3.47.1 / Dart 3.13.1:

```text
dart run tool/generate_bindings.dart
```

Pigeon is pinned because generated code is not a stable public API. The generator
replaces Pigeon's diagnostic exception payload with a constant redacted
`internalFailure` and replaces every generated message description with
`<redacted>` so master passwords, envelopes and payload bytes cannot appear in
diagnostic stringification. If Pigeon's template changes, generation stops for
review.

## Checks

```text
flutter analyze
flutter test
```

Android compilation additionally requires Android SDK 36. iOS compilation must
run on a supported macOS/Xcode host. Until both are evidenced, ADR-0019 stays
Proposed and the Stage 2 key-bridge item stays open.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

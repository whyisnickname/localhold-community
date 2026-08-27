<!-- SPDX-License-Identifier: MPL-2.0 -->
# Localhold Free mobile client

This is the independently buildable Free Flutter application. It has no
Localhold backend endpoint, registration, Trial, entitlement, payment,
advertising or analytics dependency. Later stages add the advertised local
vault features inside the same community boundary.

Prerequisites:

- exact Flutter revision recorded by the private foundation CI;
- Android SDK for Android builds;
- Xcode on macOS for iOS builds.

After dependency resolution from the committed lockfile, the acceptance flow
runs format/analyze/unit checks and unsigned Android/iOS builds. Official store
identities and signing keys are not part of this source distribution.

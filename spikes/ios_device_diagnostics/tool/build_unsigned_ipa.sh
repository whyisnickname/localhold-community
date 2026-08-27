#!/usr/bin/env sh
# SPDX-License-Identifier: MPL-2.0
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <verified-libsodium-root> <git-revision> <output-directory>" >&2
  exit 64
fi

LIBSODIUM_ROOT=$1
BUILD_REVISION=$2
OUTPUT_DIRECTORY=$3

case "$BUILD_REVISION" in
  *[!0-9a-fA-F]*|'')
    echo "build revision must contain 7-64 hexadecimal characters" >&2
    exit 65
    ;;
esac
if [ "${#BUILD_REVISION}" -lt 7 ] || [ "${#BUILD_REVISION}" -gt 64 ]; then
  echo "build revision must contain 7-64 hexadecimal characters" >&2
  exit 65
fi

for required in \
  "$LIBSODIUM_ROOT/ios/include" \
  "$LIBSODIUM_ROOT/ios/lib/libsodium.a" \
  "community/spikes/ios_device_diagnostics/app/Info.plist" \
  "community/spikes/ios_device_diagnostics/app/Stage2DiagnosticsApp.swift"
do
  if [ ! -e "$required" ]; then
    echo "required input is missing: $required" >&2
    exit 66
  fi
done

WORK_DIRECTORY=$(mktemp -d)
cleanup() {
  rm -rf -- "$WORK_DIRECTORY"
}
trap cleanup EXIT HUP INT TERM

APP_NAME="LocalholdStage2Diagnostics"
APP_DIRECTORY="$WORK_DIRECTORY/Payload/$APP_NAME.app"
mkdir -p "$APP_DIRECTORY" "$OUTPUT_DIRECTORY"
cp community/spikes/ios_device_diagnostics/app/Info.plist "$APP_DIRECTORY/Info.plist"
plutil -replace LocalholdBuildRevision -string "$BUILD_REVISION" "$APP_DIRECTORY/Info.plist"

DEVICE_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun swiftc \
  -O \
  -whole-module-optimization \
  -parse-as-library \
  -module-name "$APP_NAME" \
  -target arm64-apple-ios15.0 \
  -sdk "$DEVICE_SDK" \
  -I "$LIBSODIUM_ROOT/ios/include" \
  community/spikes/ios_device_diagnostics/app/Stage2DiagnosticsApp.swift \
  community/spikes/argon2_calibration/ios/IOSArgon2Calibration.swift \
  community/spikes/argon2_calibration/ios/IOSArgon2EvidenceCollector.swift \
  community/spikes/nonce_allocator/ios/IOSNonceAllocatorProtocol.swift \
  community/spikes/mobile_stress/ios/IOSMobileStressHarness.swift \
  community/spikes/mobile_stress/ios/IOSMobileStressEvidenceCollector.swift \
  "$LIBSODIUM_ROOT/ios/lib/libsodium.a" \
  -framework UIKit \
  -framework CryptoKit \
  -framework Security \
  -Xlinker -dead_strip \
  -o "$APP_DIRECTORY/$APP_NAME"

if codesign --display "$APP_DIRECTORY" >/dev/null 2>&1; then
  codesign --remove-signature "$APP_DIRECTORY"
fi
if find "$APP_DIRECTORY" -name embedded.mobileprovision -o -name '*.appex' | grep .; then
  echo "diagnostic package contains a forbidden provisioning profile or extension" >&2
  exit 67
fi

ARCHITECTURES=$(lipo -archs "$APP_DIRECTORY/$APP_NAME")
if [ "$ARCHITECTURES" != "arm64" ]; then
  echo "unexpected executable architectures: $ARCHITECTURES" >&2
  exit 68
fi
if [ "$(plutil -extract MinimumOSVersion raw "$APP_DIRECTORY/Info.plist")" != "15.0" ]; then
  echo "unexpected minimum iOS version" >&2
  exit 69
fi

IPA_PATH="$OUTPUT_DIRECTORY/localhold-stage2-ios-device-$BUILD_REVISION.ipa"
(
  cd "$WORK_DIRECTORY"
  ditto -c -k --sequesterRsrc --keepParent Payload "$IPA_PATH"
)
shasum -a 256 "$IPA_PATH" > "$OUTPUT_DIRECTORY/SHA256SUMS"
cat > "$OUTPUT_DIRECTORY/BUILD_METADATA.txt" <<EOF
artifact=$(basename "$IPA_PATH")
revision=$BUILD_REVISION
architecture=arm64
minimum_ios=15.0
signing=unsigned-for-selectel-resigning-only
contains_user_data=false
EOF

unzip -t "$IPA_PATH" >/dev/null
unzip -l "$IPA_PATH"
cat "$OUTPUT_DIRECTORY/SHA256SUMS"

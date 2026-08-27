#!/usr/bin/env sh
# SPDX-License-Identifier: MPL-2.0
set -eu

VERSION="1.0.21"
ARCHIVE="libsodium-${VERSION}.tar.gz"
SOURCE_URL="https://github.com/jedisct1/libsodium/releases/download/${VERSION}-RELEASE/${ARCHIVE}"
EXPECTED_SHA256="9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf"
MINISIGN_KEY="RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <android-ndk-directory> <output-directory>" >&2
  exit 64
fi

ANDROID_NDK_DIRECTORY=$1
OUTPUT_DIRECTORY=$2

for command_name in awk curl minisign sha256sum tar make zip; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "required command is unavailable: $command_name" >&2
    exit 69
  fi
done

if [ ! -f "$ANDROID_NDK_DIRECTORY/source.properties" ]; then
  echo "invalid Android NDK directory" >&2
  exit 65
fi

WORK_DIRECTORY=$(mktemp -d)
cleanup() {
  rm -rf -- "$WORK_DIRECTORY"
}
trap cleanup EXIT HUP INT TERM

curl --fail --location --proto '=https' --tlsv1.2 \
  --output "$WORK_DIRECTORY/$ARCHIVE" "$SOURCE_URL"
curl --fail --location --proto '=https' --tlsv1.2 \
  --output "$WORK_DIRECTORY/$ARCHIVE.minisig" "$SOURCE_URL.minisig"

ACTUAL_SHA256=$(sha256sum "$WORK_DIRECTORY/$ARCHIVE" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "libsodium source checksum mismatch" >&2
  exit 66
fi

minisign -Vm "$WORK_DIRECTORY/$ARCHIVE" -P "$MINISIGN_KEY"
tar -xzf "$WORK_DIRECTORY/$ARCHIVE" -C "$WORK_DIRECTORY"

SOURCE_DIRECTORY="$WORK_DIRECTORY/libsodium-${VERSION}"
(
  cd "$SOURCE_DIRECTORY"
  ANDROID_NDK_HOME="$ANDROID_NDK_DIRECTORY" \
    NDK_PLATFORM="android-24" \
    ./dist-build/android-aar.sh
)

mkdir -p "$OUTPUT_DIRECTORY"
cp "$SOURCE_DIRECTORY/libsodium-${VERSION}.0.aar" "$OUTPUT_DIRECTORY/"
sha256sum "$OUTPUT_DIRECTORY/libsodium-${VERSION}.0.aar" \
  > "$OUTPUT_DIRECTORY/libsodium-${VERSION}.0.aar.sha256"

if command -v xcodebuild >/dev/null 2>&1; then
  (
    cd "$SOURCE_DIRECTORY"
    ./dist-build/apple-xcframework.sh
  )
  cp -R "$SOURCE_DIRECTORY/libsodium-apple/Clibsodium.xcframework" "$OUTPUT_DIRECTORY/"
else
  echo "xcodebuild unavailable; Apple XCFramework was not built" >&2
fi

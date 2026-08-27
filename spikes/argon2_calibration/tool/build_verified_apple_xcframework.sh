#!/usr/bin/env sh
# SPDX-License-Identifier: MPL-2.0
set -eu

VERSION="1.0.21"
ARCHIVE="libsodium-${VERSION}.tar.gz"
SOURCE_URL="https://github.com/jedisct1/libsodium/releases/download/${VERSION}-RELEASE/${ARCHIVE}"
EXPECTED_SHA256="9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf"
MINISIGN_KEY="RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <output-directory>" >&2
  exit 64
fi
OUTPUT_DIRECTORY=$1

for command_name in awk curl minisign shasum tar make xcodebuild; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "required command is unavailable: $command_name" >&2
    exit 69
  fi
done

WORK_DIRECTORY=$(mktemp -d)
cleanup() {
  rm -rf -- "$WORK_DIRECTORY"
}
trap cleanup EXIT HUP INT TERM

curl --fail --location --proto '=https' --tlsv1.2 \
  --output "$WORK_DIRECTORY/$ARCHIVE" "$SOURCE_URL"
curl --fail --location --proto '=https' --tlsv1.2 \
  --output "$WORK_DIRECTORY/$ARCHIVE.minisig" "$SOURCE_URL.minisig"

ACTUAL_SHA256=$(shasum -a 256 "$WORK_DIRECTORY/$ARCHIVE" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "libsodium source checksum mismatch" >&2
  exit 66
fi
minisign -Vm "$WORK_DIRECTORY/$ARCHIVE" -P "$MINISIGN_KEY"
tar -xzf "$WORK_DIRECTORY/$ARCHIVE" -C "$WORK_DIRECTORY"

SOURCE_DIRECTORY="$WORK_DIRECTORY/libsodium-${VERSION}"
(
  cd "$SOURCE_DIRECTORY"
  ./configure --disable-shared
  make -j2
  make check
  make distclean
)
(
  cd "$SOURCE_DIRECTORY"
  LIBSODIUM_MINIMAL_BUILD=1 \
    IOS_VERSION_MIN=15.0.0 \
    IOS_SIMULATOR_VERSION_MIN=15.0.0 \
    ./dist-build/apple-xcframework.sh
)

mkdir -p "$OUTPUT_DIRECTORY"
cp -R "$SOURCE_DIRECTORY/libsodium-apple/Clibsodium.xcframework" "$OUTPUT_DIRECTORY/"
cp -R "$SOURCE_DIRECTORY/libsodium-apple/macos" "$OUTPUT_DIRECTORY/"
cp -R "$SOURCE_DIRECTORY/libsodium-apple/ios" "$OUTPUT_DIRECTORY/"
cp -R "$SOURCE_DIRECTORY/libsodium-apple/ios-simulators" "$OUTPUT_DIRECTORY/"
(
  cd "$OUTPUT_DIRECTORY"
  find . -type f ! -name SHA256SUMS -exec shasum -a 256 {} \; | sort
) > "$WORK_DIRECTORY/SHA256SUMS"
cp "$WORK_DIRECTORY/SHA256SUMS" "$OUTPUT_DIRECTORY/SHA256SUMS"

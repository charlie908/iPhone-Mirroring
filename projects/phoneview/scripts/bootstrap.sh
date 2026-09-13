#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES_DIR="$KIT_ROOT/Sources"

if [[ -e "$SOURCES_DIR" ]]; then
  echo "Refusing to overwrite existing directory: $SOURCES_DIR" >&2
  exit 1
fi

mkdir -p "$SOURCES_DIR"

git clone https://github.com/himanshkukreja/ios-web-streamer.git "$SOURCES_DIR/ios-web-streamer"
git -C "$SOURCES_DIR/ios-web-streamer" checkout cfb1504638d3f9298704fb8f3ad9ebd06d60e148
git -C "$SOURCES_DIR/ios-web-streamer" apply "$KIT_ROOT/patches/ios-web-streamer.patch"

git clone https://github.com/mobile-next/devicekit-ios.git "$SOURCES_DIR/devicekit-ios"
git -C "$SOURCES_DIR/devicekit-ios" checkout 510d10e5e376221397cef7f8d7acb74603c61888
git -C "$SOURCES_DIR/devicekit-ios" apply "$KIT_ROOT/patches/devicekit-ios.patch"

echo "PhoneView sources are ready in $SOURCES_DIR"
echo "Next: read the signing and identifier setup in README.md"


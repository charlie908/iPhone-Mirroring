#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES_DIR="$PROJECT_DIR/Sources"
TARGET_DIR="$SOURCES_DIR/devicekit-ios"

if [[ -e "$TARGET_DIR" ]]; then
  echo "Refusing to overwrite existing directory: $TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$SOURCES_DIR"
git clone https://github.com/mobile-next/devicekit-ios.git "$TARGET_DIR"
git -C "$TARGET_DIR" checkout 510d10e5e376221397cef7f8d7acb74603c61888
git -C "$TARGET_DIR" apply "$PROJECT_DIR/devicekit-ios.patch"

echo "DeviceKit is ready in $TARGET_DIR"


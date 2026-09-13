#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 IPHONE_XCODE_DESTINATION_ID" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVICEKIT_DIR="$KIT_ROOT/Sources/devicekit-ios"

if [[ ! -d "$DEVICEKIT_DIR/devicekit-ios.xcodeproj" ]]; then
  echo "Run ./scripts/bootstrap.sh first." >&2
  exit 1
fi

cd "$DEVICEKIT_DIR"
exec xcodebuild test \
  -project devicekit-ios.xcodeproj \
  -scheme devicekit-ios \
  -configuration Debug \
  -destination "id=$1" \
  -only-testing:devicekit-iosUITests/DeviceKitUITests/testRunAutomation


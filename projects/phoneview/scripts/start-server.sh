#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 IPHONE_IP" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$KIT_ROOT/Sources/ios-web-streamer/server"
PYTHON_BIN="$SERVER_DIR/.venv/bin/python"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Run ./scripts/setup-mac.sh first." >&2
  exit 1
fi

cd "$SERVER_DIR"
exec "$PYTHON_BIN" main.py --port 8999 --wda-host "$1"


#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$KIT_ROOT/Sources/ios-web-streamer/server"

if [[ ! -f "$SERVER_DIR/requirements.txt" ]]; then
  echo "Run ./scripts/bootstrap.sh first." >&2
  exit 1
fi

PYTHON_BIN="${PYTHON_BIN:-python3}"
"$PYTHON_BIN" -m venv "$SERVER_DIR/.venv"
"$SERVER_DIR/.venv/bin/python" -m pip install --upgrade pip
"$SERVER_DIR/.venv/bin/python" -m pip install -r "$SERVER_DIR/requirements.txt"

echo "Mac relay environment created at $SERVER_DIR/.venv"


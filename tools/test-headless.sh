#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --path . --script res://tests/run_all.gd

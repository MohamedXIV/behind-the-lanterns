#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
engine_version="$("$GODOT_BIN" --version)"
if [[ "$engine_version" != 4.7.2.stable.* ]]; then
  echo "Expected Godot Standard 4.7.2 stable; found $engine_version" >&2
  exit 1
fi
task_logs="$(mktemp -d)"
trap 'rm -rf "$task_logs"' EXIT

run_checked() {
  local stage="$1"
  shift
  local stage_log="$task_logs/$stage.log"
  if ! "$GODOT_BIN" --headless --path . "$@" >"$stage_log" 2>&1; then
    cat "$stage_log"
    exit 1
  fi
  # Godot can exit zero after script errors. A test marker alone is insufficient.
  if grep -Eq 'SCRIPT ERROR:|ERROR:|WARNING:|FAIL:' "$stage_log"; then
    cat "$stage_log"
    exit 1
  fi
  if [[ "$stage" != import ]]; then cat "$stage_log"; fi
}

echo "Engine: $engine_version"
run_checked import --editor --import --quit
run_checked contracts --script res://tests/run_all.gd
restart_directory="user://foundation-restart-$$"
run_checked restart-write --script res://tests/restart.gd -- write "$restart_directory"
run_checked restart-read --script res://tests/restart.gd -- read "$restart_directory"
run_checked startup --quit-after 2
echo "HEADLESS VERIFICATION PASS"

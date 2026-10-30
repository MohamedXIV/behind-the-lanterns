#!/usr/bin/env bash
set -euo pipefail

PRESET="${1:-Web smoke}"
OUTPUT="${2:-build/web/index.html}"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/4.7.2.stable"

if [[ ! -f "${TEMPLATE_DIR}/web_nothreads_release.zip" && ! -f "${TEMPLATE_DIR}/web_nothreads_debug.zip" ]]; then
  echo "BLOCKED: Godot 4.7.2 Web export templates not found in ${TEMPLATE_DIR}." >&2
  echo "Install Godot_v4.7.2-stable_export_templates.tpz into ${TEMPLATE_DIR} to produce ${OUTPUT}." >&2
  exit 2
fi

mkdir -p "$(dirname "${OUTPUT}")"
godot --headless --path . --export-release "${PRESET}" "${OUTPUT}"
echo "WEB EXPORT READY: ${OUTPUT}"

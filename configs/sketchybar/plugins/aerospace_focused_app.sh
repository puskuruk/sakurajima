#!/usr/bin/env bash
set -Eeuo pipefail

APP="$(aerospace list-windows --focused --format "%{app-name}" 2>/dev/null || true)"
sketchybar --set focused_app label="${APP:-—}"
#!/usr/bin/env bash
set -Eeuo pipefail

SPACE_ID="${1:?space id required}"

FOCUSED="$(aerospace list-workspaces --focused | head -n1 || true)"

if [[ "$SPACE_ID" == "$FOCUSED" ]]; then
  sketchybar --set "space.${SPACE_ID}" background.color=0xffa6da95
else
  sketchybar --set "space.${SPACE_ID}" background.color=0x00000000
fi

#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
fi

# 🏴 SAKURAJIMA AEROSPACE CONFIG GENERATOR — 0.1.0-alpha
#
# Reads base template:
#   ~/.config/aerospace.base.toml
# Writes generated:
#   ~/.config/aerospace.toml
#
# Injects generated client bindings between markers.

BASE="${HOME}/.config/aerospace.base.toml"
OUT="${HOME}/.config/aerospace.toml"
CLIENTS_DIR="${HOME}/workspace/clients"

BEGIN="# >>> SAKURAJIMA GENERATED CLIENTS >>>"
END="# <<< SAKURAJIMA GENERATED CLIENTS <<<"

[[ -f "$BASE" ]] || { echo "❌ Missing base template: $BASE" >&2; exit 2; }
mkdir -p "${HOME}/.config"

mapfile -t clients < <(
  [[ -d "$CLIENTS_DIR" ]] && find "$CLIENTS_DIR" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null \
    | sed "s|^${CLIENTS_DIR}/||" \
    | grep -vE '^(_archive|\.)' \
    | LC_ALL=C sort || true
)

# Limit to 9 for stable key mapping
clients=("${clients[@]:0:9}")

tmp="$(mktemp)"
block="$(mktemp)"

# Cleanup trap for temporary files
trap 'rm -f "$tmp" "$block"' EXIT ERR INT TERM

{
  i=1
  for c in "${clients[@]}"; do
    echo "ctrl-alt-cmd-${i} = 'workspace ${c}'"
    echo "ctrl-alt-cmd-shift-${i} = 'move-node-to-workspace ${c}'"
    echo
    i=$((i+1))
  done

  echo "# Mapping (generated):"
  i=1
  for c in "${clients[@]}"; do
    echo "#   ${i} -> ${c}"
    i=$((i+1))
  done
} > "$block"

awk -v b="$BEGIN" -v e="$END" -v blockfile="$block" '
  BEGIN{inside=0}
  $0==b { print; while ((getline line < blockfile) > 0) print line; close(blockfile); inside=1; next }
  $0==e { inside=0; print; next }
  inside==0 { print }
' "$BASE" > "$tmp"

# If OUT exists as symlink (legacy), remove it so OUT becomes a real generated file
if [[ -L "$OUT" ]]; then
  rm "$OUT"
fi

mv "$tmp" "$OUT"

echo "✅ Generated: $OUT"
echo "ℹ️  Clients mapped to ctrl-alt-cmd-[1..9] (sorted)."

#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    # Fallback definitions if common.sh not found
    die() { printf "❌ %s\n" "$*"; exit 2; }
    ok()  { printf "✅ %s\n" "$*"; }
    info(){ printf "ℹ️  %s\n" "$*"; }
fi

# 🏴 SAKURAJIMA AEROSPACE UPDATE — 0.1.0-alpha
# Regenerate config, validate bindings (no duplicates), then reload AeroSpace.

GEN="${HOME}/.local/bin/generate-aerospace-config"
FALLBACK="${HOME}/setup/scripts/generate-aerospace-config.sh"
OUT="${HOME}/.config/aerospace.toml"

if [[ -x "$GEN" ]]; then
  info "Generating AeroSpace config via: $GEN"
  "$GEN"
elif [[ -x "$FALLBACK" ]]; then
  info "Generating AeroSpace config via: $FALLBACK"
  "$FALLBACK"
else
  die "generate-aerospace-config not found (expected $GEN or $FALLBACK)"
fi

[[ -f "$OUT" ]] || die "Generated config missing: $OUT"

python3 - <<'PY'
import re, collections, pathlib, sys

p = pathlib.Path.home()/".config/aerospace.toml"
txt = p.read_text()

m = re.search(r'\[mode\.main\.binding\](.*?)(\n\[|\Z)', txt, flags=re.S)
if not m:
    print("❌ No [mode.main.binding] block found in ~/.config/aerospace.toml")
    sys.exit(2)

block = m.group(1)
keys = []
for line in block.splitlines():
    s = line.strip()
    if not s or s.startswith("#"):
        continue
    if "=" not in s:
        continue
    k = s.split("=", 1)[0].strip()
    keys.append(k)

c = collections.Counter(keys)
dupes = [(k, v) for k, v in c.items() if v > 1]
print(f"✅ Parsed {len(keys)} bindings from ~/.config/aerospace.toml")

if dupes:
    print("❌ DUPLICATE KEYS (these will shadow each other):")
    for k, v in sorted(dupes):
        print(f"  {k}  x{v}")
    sys.exit(2)

print("✅ No duplicate bindings found.")
PY

command -v aerospace >/dev/null 2>&1 || die "aerospace CLI not found in PATH"

info "Reloading AeroSpace config…"
aerospace reload-config

ok "AeroSpace updated + reloaded"

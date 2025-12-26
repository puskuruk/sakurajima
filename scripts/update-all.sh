#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ok(){ printf "✅ %s\n" "$*"; }
info(){ printf "ℹ️  %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*"; }
die(){ printf "❌ %s\n" "$*"; exit 2; }

SETUP_DIR="${HOME}/setup"
BREWFILE="${SETUP_DIR}/Brewfile"
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

[[ -f "$BREWFILE" ]] || die "Missing Brewfile: $BREWFILE"
command -v brew >/dev/null 2>&1 || die "Homebrew not found in PATH"

info "Updating Sakurajima repo..."
if git -C "$SETUP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$SETUP_DIR" pull || warn "Repo update failed"
else
  warn "Not a git repo: $SETUP_DIR (skipping pull)"
fi

info "brew bundle"
brew bundle --file "$BREWFILE"

info "Regenerate AeroSpace config"
command -v generate-aerospace-config >/dev/null 2>&1 || die "generate-aerospace-config not found in PATH"
generate-aerospace-config

info "Regenerate Raycast commands"
command -v generate-sakurajima-commands >/dev/null 2>&1 || die "generate-sakurajima-commands not found in PATH"
generate-sakurajima-commands

info "Update macOS native shortcuts bridge"
if command -v update-aerospace-native-shortcuts >/dev/null 2>&1; then
  update-aerospace-native-shortcuts || warn "Native shortcuts bridge update had warnings"
else
  "${SETUP_DIR}/scripts/update-aerospace-native-shortcuts.sh" || warn "Native shortcuts bridge update had warnings"
fi

info "Reload AeroSpace (if available)"
if command -v aerospace >/dev/null 2>&1; then
  aerospace reload-config || warn "AeroSpace reload had warnings"
fi

info "Refresh simple-bar via Übersicht"
osascript -e 'tell application id "tracesOf.Uebersicht" to refresh widget id "simple-bar-index-jsx"' 2>/dev/null || true

info "Verify system"
command -v verify-system >/dev/null 2>&1 || die "verify-system not found in PATH"
verify-system

ok "Update-all complete"

#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "✅ %s\n" "$*"; }
info() { printf "ℹ️  %s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*"; }
die()  { printf "❌ %s\n" "$*"; exit "${2:-2}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

HOME_DIR="$HOME"
SETUP_DIR="$HOME_DIR/setup"

XDG_CONFIG="$HOME_DIR/.config"
XDG_LOCAL="$HOME_DIR/.local"
LOCAL_BIN="$XDG_LOCAL/bin"

WORKSPACE="$HOME_DIR/workspace"
CLIENTS="$WORKSPACE/clients"
ARCHIVE="$CLIENTS/_archive"
PERSONAL="$WORKSPACE/personal"
SHARED="$WORKSPACE/shared"
SCRATCH="$WORKSPACE/scratch"

SSH_DIR="$HOME_DIR/.ssh"
SSH_KEYS="$SSH_DIR/keys"
SSH_CONFIG="$SSH_DIR/config"

expect_symlink() {
  local dest="$1" src="$2"
  [[ -L "$dest" ]] || die "Expected symlink: $dest"
  local cur; cur="$(readlink "$dest" || true)"
  [[ "$cur" == "$src" ]] || die "Symlink mismatch: $dest -> $cur (expected $src)"
  ok "Symlink OK: $dest -> $src"
}

scan_broken_symlinks() {
  info "Scanning broken symlinks in HOME (no cross-device)…"
  local broken
  broken="$(find "$HOME_DIR" -xdev -type l ! -exec test -e {} \; -print 2>/dev/null || true)"
  if [[ -n "$broken" ]]; then
    echo "$broken" | sed 's/^/  - /'
    die "Broken symlinks found. Fix/remove them."
  fi
  ok "No broken symlinks"
}

check_ssh_perms() {
  [[ -d "$SSH_DIR" ]] || die "Missing: $SSH_DIR"
  [[ -d "$SSH_KEYS" ]] || die "Missing: $SSH_KEYS"
  [[ -f "$SSH_CONFIG" ]] || die "Missing: $SSH_CONFIG"

  local p
  p="$(stat -f "%Lp" "$SSH_DIR" 2>/dev/null || true)"
  [[ "$p" == "700" ]] || die "~/.ssh perms must be 700 (got $p)"
  p="$(stat -f "%Lp" "$SSH_KEYS" 2>/dev/null || true)"
  [[ "$p" == "700" ]] || die "~/.ssh/keys perms must be 700 (got $p)"
  p="$(stat -f "%Lp" "$SSH_CONFIG" 2>/dev/null || true)"
  [[ "$p" == "600" ]] || die "~/.ssh/config perms must be 600 (got $p)"
  ok "SSH permissions OK"
}

brew_doctor_strict() {
  command_exists brew || die "brew missing"
  info "brew doctor (strict)…"
  local out
  out="$(brew doctor 2>&1 || true)"
  echo "$out" | sed 's/^/  /'
  if echo "$out" | grep -qE '^Error:'; then
    die "brew doctor reported errors"
  fi
  ok "brew doctor OK (no errors)"
}

bold "🩺 VERIFY SYSTEM — SAKURAJIMA (0.1.0-alpha)"

[[ -d "$SETUP_DIR" ]] || die "Missing repo: $SETUP_DIR"
for d in "$WORKSPACE" "$CLIENTS" "$ARCHIVE" "$PERSONAL" "$SHARED" "$SCRATCH" "$XDG_CONFIG" "$XDG_LOCAL" "$LOCAL_BIN"; do
  [[ -d "$d" ]] || die "Missing directory: $d"
done
ok "Directory layout OK"

# Repo files must exist
for f in \
  "$SETUP_DIR/Brewfile" \
  "$SETUP_DIR/configs/.zshrc" \
  "$SETUP_DIR/configs/.gitconfig.template" \
  "$SETUP_DIR/configs/starship.toml" \
  "$SETUP_DIR/configs/aerospace.base.toml" \
  "$SETUP_DIR/raycast/workflows.json" \
  "$SETUP_DIR/raycast/generate-sakurajima-commands.sh" \
  "$SETUP_DIR/infra/docker-compose.yml" \
  "$SETUP_DIR/docs/onboarding-playbook.md" \
  "$SETUP_DIR/docs/new-hire-checklist.md"
do
  [[ -f "$f" ]] || die "Missing repo file: $f"
done
ok "Repo contents OK"

# Expected symlinks
expect_symlink "$HOME_DIR/.zshrc" "$SETUP_DIR/configs/.zshrc"
expect_symlink "$XDG_CONFIG/starship.toml" "$SETUP_DIR/configs/starship.toml"

# .gitconfig should exist as regular file (copied from template, not symlinked)
[[ -f "$HOME_DIR/.gitconfig" ]] || warn "Missing: $HOME_DIR/.gitconfig (should be copied from template)"
[[ -f "$HOME_DIR/.gitconfig.local" ]] || warn "Missing: $HOME_DIR/.gitconfig.local (contains personal git identity)"
[[ -f "$XDG_CONFIG/aerospace.toml" ]] || die "Missing: $XDG_CONFIG/aerospace.toml"

check_ssh_perms
# scan_broken_symlinks  <-- Disabled (too slow)
brew_doctor_strict

info "Checking required binaries…"
req=(git ssh ssh-keygen awk sed grep find)
for b in "${req[@]}"; do command_exists "$b" || die "Missing required binary: $b"; done
ok "Core binaries OK"

info "Checking expected installed commands…"
expected=(verify-system new-client generate-aerospace-config update-aerospace sakurajima-confirm kubectl-guard terraform-guard update-all macos-defaults sakurajima-infra-up sakurajima-infra-down generate-sakurajima-commands)
for b in "${expected[@]}"; do command_exists "$b" || die "Missing expected command on PATH: $b"; done
ok "Installed commands OK"

bold "✅ VERIFY PASS"

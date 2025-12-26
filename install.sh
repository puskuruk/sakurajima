#!/usr/bin/env bash
#
# Sakurajima Bootstrap Script
#
# This script bootstraps the Sakurajima environment by:
# 1. Installing Homebrew (if needed)
# 2. Installing mise and core dependencies
# 3. Setting up Node.js via mise
# 4. Installing npm dependencies (zx)
# 5. Handing off to the zx-based installer
#
# Usage: ./install.sh
#
set -Eeuo pipefail
IFS=$'\n\t'

# =============================================================================
# Output Helpers
# =============================================================================

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
info() { printf "\033[1m→\033[0m %s\n" "$*"; }
warn() { printf "\033[33m⚠\033[0m %s\n" "$*"; }
die()  { printf "\033[31m✗\033[0m %s\n" "$*"; exit "${2:-1}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# Environment Validation
# =============================================================================

[[ "$(uname -s)" == "Darwin" ]] || die "This installer supports macOS only."

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

if [[ "$SETUP_DIR" != "$HOME_DIR/setup" ]]; then
  die "Path inconsistency: Repo MUST be at ~/setup. Current: $SETUP_DIR
Run: mv \"$SETUP_DIR\" ~/setup && cd ~/setup && ./install.sh"
fi

# =============================================================================
# Banner
# =============================================================================

LOGO_SCRIPT="$SETUP_DIR/scripts/sakurajima-logo"
if [[ -x "$LOGO_SCRIPT" ]]; then
  bash "$LOGO_SCRIPT"
  echo
  printf "\033[2mBootstrap v0.2.0\033[0m\n"
else
  cat << 'EOF'

        SAKURAJIMA
       Bootstrap v0.2.0

EOF
fi

bold "Starting Sakurajima bootstrap..."
echo

# =============================================================================
# XCode Command Line Tools
# =============================================================================

if ! xcode-select -p >/dev/null 2>&1; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo
  warn "Please complete the Xcode Command Line Tools installation"
  warn "Then re-run: ./install.sh"
  exit 0
fi
ok "Xcode Command Line Tools installed"

# =============================================================================
# Homebrew
# =============================================================================

ZPROFILE="$HOME_DIR/.zprofile"

install_homebrew() {
  if command_exists brew; then
    ok "Homebrew already installed"
    return
  fi

  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew installation failed"

  # Set up shell environment
  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$ZPROFILE"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$ZPROFILE"
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "brew not found after installation"
  fi

  ok "Homebrew installed"
}

install_homebrew
echo

# =============================================================================
# Core Dependencies (Homebrew)
# =============================================================================

info "Installing core dependencies..."

brew update >/dev/null 2>&1 || die "brew update failed"

# Install from Brewfile
brew bundle --file="$SETUP_DIR/Brewfile" || die "brew bundle failed"
brew cleanup >/dev/null 2>&1 || true

ok "Core dependencies installed"
echo

# =============================================================================
# mise + Node.js
# =============================================================================

setup_mise() {
  if ! command_exists mise; then
    die "mise not found after brew bundle. Check Brewfile."
  fi

  # Activate mise in current shell
  eval "$(mise activate bash)"

  # Ensure Node.js is installed (mise will use .mise.toml or default)
  if ! mise list node 2>/dev/null | grep -q "node"; then
    info "Installing Node.js via mise..."
    mise use --global node@lts
  fi

  ok "Node.js ready ($(node --version))"
}

setup_mise
echo

# =============================================================================
# npm Dependencies (zx)
# =============================================================================

info "Installing npm dependencies..."

cd "$SETUP_DIR"

# Install dependencies from package.json
npm install --silent || die "npm install failed"

ok "npm dependencies installed"
echo

# =============================================================================
# Verify zx is Available
# =============================================================================

if ! command_exists zx && ! [[ -x "$SETUP_DIR/node_modules/.bin/zx" ]]; then
  die "zx not found after npm install. Check package.json."
fi

ok "zx is available"
echo

# =============================================================================
# Hand Off to zx Installer
# =============================================================================

bold "Bootstrap complete. Starting main installation..."
echo

# Use local zx from node_modules
ZX="$SETUP_DIR/node_modules/.bin/zx"

if [[ -x "$ZX" ]]; then
  exec "$ZX" "$SETUP_DIR/src/install.ts"
else
  # Fall back to global zx
  exec zx "$SETUP_DIR/src/install.ts"
fi

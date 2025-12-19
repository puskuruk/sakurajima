#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "✅ %s\n" "$*"; }
info() { printf "ℹ️  %s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*"; }
die()  { printf "❌ %s\n" "$*"; exit "${2:-2}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This installer supports macOS only."

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

if [[ "$SETUP_DIR" != "$HOME_DIR/setup" ]]; then
  die "Path Inconsistency: Repo MUST be installed at ~/setup. Current: $SETUP_DIR\nRun: mv \"$SETUP_DIR\" ~/setup"
fi

CONFIGS_DIR="$SETUP_DIR/configs"
SCRIPTS_DIR="$SETUP_DIR/scripts"
RAYCAST_DIR="$SETUP_DIR/raycast"
INFRA_DIR="$SETUP_DIR/infra"
DOCS_DIR="$SETUP_DIR/docs"
BREWFILE="$SETUP_DIR/Brewfile"

XDG_CONFIG="$HOME_DIR/.config"
XDG_LOCAL="$HOME_DIR/.local"
LOCAL_BIN="$XDG_LOCAL/bin"
export PATH="$LOCAL_BIN:$PATH"

WORKSPACE="$HOME_DIR/workspace"
CLIENTS="$WORKSPACE/clients"
CLIENTS_ARCHIVE="$CLIENTS/_archive"
PERSONAL="$WORKSPACE/personal"
SHARED="$WORKSPACE/shared"
SCRATCH="$WORKSPACE/scratch"
DATA="$WORKSPACE/data"

SSH_DIR="$HOME_DIR/.ssh"
SSH_KEYS="$SSH_DIR/keys"
SSH_CONFIG="$SSH_DIR/config"

ZPROFILE="$HOME_DIR/.zprofile"

require_file() { [[ -f "$1" ]] || die "Missing required file: $1"; }
require_dir()  { [[ -d "$1" ]] || die "Missing required directory: $1"; }

ensure_dir() { mkdir -p "$@"; }

ensure_symlink_strict() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || die "Source missing for symlink: $src"
  ensure_dir "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    local cur; cur="$(readlink "$dest")"
    [[ "$cur" == "$src" ]] && { ok "Symlink OK: $dest"; return 0; }
    die "Refusing to overwrite existing symlink: $dest -> $cur"
  fi
  [[ -e "$dest" ]] && die "Refusing to overwrite real file: $dest"
  ln -s "$src" "$dest"
  ok "Symlink created: $dest -> $src"
}

append_line_once() {
  local file="$1" line="$2"
  ensure_dir "$(dirname "$file")"
  touch "$file"
  grep -Fqx "$line" "$file" || echo "$line" >> "$file"
}

ensure_ssh() {
  ensure_dir "$SSH_DIR" "$SSH_KEYS"
  touch "$SSH_CONFIG"
  chmod 700 "$SSH_DIR" "$SSH_KEYS" || true
  chmod 600 "$SSH_CONFIG" || true

  if ! grep -q "^# >>> SAKURAJIMA MANAGED CLIENT HOSTS >>>$" "$SSH_CONFIG"; then
    cat >> "$SSH_CONFIG" <<'EOF'

# >>> SAKURAJIMA MANAGED CLIENT HOSTS >>>
# (managed by new-client.sh)
# <<< SAKURAJIMA MANAGED CLIENT HOSTS <<<

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityAgent none
EOF
  fi

  ok "SSH ensured"
}

install_homebrew() {
  if command_exists brew; then ok "Homebrew already installed"; return; fi
  info "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew installation failed"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    append_line_once "$ZPROFILE" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    append_line_once "$ZPROFILE" 'eval "$(/usr/local/bin/brew shellenv)"'
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "brew not found after installation"
  fi
}

brew_bundle() {
  require_file "$BREWFILE"
  info "brew update"
  brew update || die "brew update failed"
  info "brew bundle"
  brew bundle --file "$BREWFILE" || die "brew bundle failed"
  brew cleanup || true
  ok "Brewfile applied"
}

install_script() {
  local src="$1" name="$2"
  ensure_dir "$LOCAL_BIN"
  local dest="$LOCAL_BIN/$name"

  # If dest is a symlink/hardlink to the same file, cp can fail with
  # "are identical (not copied)" which aborts under `set -e`.
  rm -f "$dest"

  if command_exists install; then
    install -m 0755 "$src" "$dest"
  else
    cp "$src" "$dest"
    chmod +x "$dest"
  fi
  ok "Installed: $name"
}

# Run branding immediately
if [[ -x "$SCRIPTS_DIR/sakurajima-logo" ]]; then
  "$SCRIPTS_DIR/sakurajima-logo"
else
  cat << "EOF"
      🌸
     🌸🌸
    🌸  🌸
   🌸    🌸
  SAKURAJIMA
 (Installer 0.1.0-alpha)
EOF
fi

bold "🏴 SAKURAJIMA INSTALLER (0.1.0-alpha)"

# Repo integrity
require_dir "$CONFIGS_DIR"
require_dir "$SCRIPTS_DIR"
require_dir "$RAYCAST_DIR"
require_dir "$INFRA_DIR"
require_dir "$DOCS_DIR"

require_file "$BREWFILE"
require_file "$CONFIGS_DIR/.zshrc"
require_file "$CONFIGS_DIR/.gitconfig.template"
require_file "$CONFIGS_DIR/starship.toml"
require_file "$CONFIGS_DIR/aerospace.base.toml"
require_file "$CONFIGS_DIR/lazygit/config.yml"
require_file "$CONFIGS_DIR/rectangle.json"

# SketchyBar configs
require_file "$CONFIGS_DIR/sketchybar/sketchybar.conf"
require_file "$CONFIGS_DIR/sketchybar/plugins/aerospace_space.sh"
require_file "$CONFIGS_DIR/sketchybar/plugins/aerospace_focused_app.sh"

# Native macOS Shortcuts bridge (NEW)
require_file "$SCRIPTS_DIR/install-aerospace-native-shortcuts.sh"
require_file "$SCRIPTS_DIR/update-aerospace-native-shortcuts.sh"

require_file "$SCRIPTS_DIR/verify-system.sh"
require_file "$SCRIPTS_DIR/new-client.sh"
require_file "$SCRIPTS_DIR/generate-aerospace-config.sh"
require_file "$SCRIPTS_DIR/update-aerospace.sh"
require_file "$SCRIPTS_DIR/sakurajima-confirm"
require_file "$SCRIPTS_DIR/kubectl-guard"
require_file "$SCRIPTS_DIR/terraform-guard"
require_file "$SCRIPTS_DIR/update-all.sh"
require_file "$SCRIPTS_DIR/macos-defaults.sh"
require_file "$SCRIPTS_DIR/sakurajima-infra-up.sh"
require_file "$SCRIPTS_DIR/sakurajima-infra-down.sh"
require_file "$SCRIPTS_DIR/sakurajima-infra-backup.sh"
require_file "$SCRIPTS_DIR/skr"
require_file "$SCRIPTS_DIR/sakurajima-logo"
require_file "$SCRIPTS_DIR/setup-local-ai.sh"
require_file "$SCRIPTS_DIR/sakurajima-time-init.sh"
require_file "$SCRIPTS_DIR/sakurajima-time-start.sh"
require_file "$SCRIPTS_DIR/sakurajima-time-cleanup.sh"
require_file "$SCRIPTS_DIR/sakurajima-time-tracker-daemon.sh"
require_file "$SCRIPTS_DIR/sakurajima-unfocus.sh"
require_file "$SCRIPTS_DIR/sakurajima-stats.sh"
require_file "$SCRIPTS_DIR/lib/common.sh"

require_file "$RAYCAST_DIR/workflows.json"
require_file "$RAYCAST_DIR/generate-sakurajima-commands.sh"

require_file "$INFRA_DIR/docker-compose.yml"
require_file "$DOCS_DIR/onboarding-playbook.md"
require_file "$DOCS_DIR/new-hire-checklist.md"
require_file "$DOCS_DIR/how-to-use.md"
require_file "$DOCS_DIR/shortcuts.md"
require_file "$DOCS_DIR/chromium-build.md"

require_file "$SETUP_DIR/INSTALL.md"

# OS prerequisites
xcode-select -p >/dev/null 2>&1 || die "Xcode Command Line Tools not installed"

# Invariants
ensure_dir "$WORKSPACE" "$CLIENTS" "$CLIENTS_ARCHIVE" "$PERSONAL" "$SHARED" "$SCRATCH" "$DATA"
ensure_dir "$XDG_CONFIG" "$LOCAL_BIN"
ensure_dir "$HOME_DIR/.config/git/clients"
touch "$HOME_DIR/.config/git/ignore"

ensure_ssh

install_homebrew
brew_bundle

# Config symlinks (strict)
ensure_symlink_strict "$CONFIGS_DIR/.zshrc" "$HOME_DIR/.zshrc"

# Copy .gitconfig template (not symlinked - allows working on ~/setup repo with personal identity)
if [[ ! -f "$HOME_DIR/.gitconfig" ]]; then
    info "Setting up git configuration..."
    cp "$CONFIGS_DIR/.gitconfig.template" "$HOME_DIR/.gitconfig"
    ok "Created ~/.gitconfig from template"
fi

# Create .gitconfig.local if it doesn't exist (for personal git identity)
if [[ ! -f "$HOME_DIR/.gitconfig.local" ]]; then
    info "Setting up personal git identity..."
    read -p "Enter your full name: " git_name
    read -p "Enter your email: " git_email
    cat > "$HOME_DIR/.gitconfig.local" <<EOF
# Personal Git Identity (not version controlled)
[user]
    name = $git_name
    email = $git_email
EOF
    ok "Created ~/.gitconfig.local"
fi

ensure_symlink_strict "$CONFIGS_DIR/starship.toml" "$XDG_CONFIG/starship.toml"

# AeroSpace: base template lives at aerospace.base.toml (generated config is aerospace.toml)
ensure_symlink_strict "$CONFIGS_DIR/aerospace.base.toml" "$XDG_CONFIG/aerospace.base.toml"

# Rectangle
ensure_symlink_strict "$CONFIGS_DIR/rectangle.json" "$XDG_CONFIG/rectangle.json"

ensure_dir "$XDG_CONFIG/lazygit"
ensure_symlink_strict "$CONFIGS_DIR/lazygit/config.yml" "$XDG_CONFIG/lazygit/config.yml"

# SketchyBar symlinks (strict)
ensure_dir "$XDG_CONFIG/sketchybar" "$XDG_CONFIG/sketchybar/plugins"
ensure_symlink_strict "$CONFIGS_DIR/sketchybar/sketchybar.conf" \
  "$XDG_CONFIG/sketchybar/sketchybar.conf"
ensure_symlink_strict "$CONFIGS_DIR/sketchybar/plugins/aerospace_space.sh" \
  "$XDG_CONFIG/sketchybar/plugins/aerospace_space.sh"
ensure_symlink_strict "$CONFIGS_DIR/sketchybar/plugins/aerospace_focused_app.sh" \
  "$XDG_CONFIG/sketchybar/plugins/aerospace_focused_app.sh"

chmod +x \
  "$XDG_CONFIG/sketchybar/sketchybar.conf" \
  "$XDG_CONFIG/sketchybar/plugins/aerospace_space.sh" \
  "$XDG_CONFIG/sketchybar/plugins/aerospace_focused_app.sh" || true

# Install scripts into ~/.local/bin
install_script "$SCRIPTS_DIR/verify-system.sh" "verify-system"
install_script "$SCRIPTS_DIR/new-client.sh" "new-client"
install_script "$SCRIPTS_DIR/generate-aerospace-config.sh" "generate-aerospace-config"
install_script "$SCRIPTS_DIR/update-aerospace.sh" "update-aerospace"
install_script "$SCRIPTS_DIR/sakurajima-confirm" "sakurajima-confirm"
install_script "$SCRIPTS_DIR/kubectl-guard" "kubectl-guard"
install_script "$SCRIPTS_DIR/terraform-guard" "terraform-guard"
install_script "$SCRIPTS_DIR/update-all.sh" "update-all"
install_script "$SCRIPTS_DIR/macos-defaults.sh" "macos-defaults"
install_script "$SCRIPTS_DIR/sakurajima-infra-up.sh" "sakurajima-infra-up"
install_script "$SCRIPTS_DIR/sakurajima-infra-down.sh" "sakurajima-infra-down"
install_script "$SCRIPTS_DIR/sakurajima-infra-backup.sh" "sakurajima-infra-backup"
install_script "$SCRIPTS_DIR/skr" "skr"
install_script "$SCRIPTS_DIR/sakurajima-logo" "sakurajima-logo"
install_script "$SCRIPTS_DIR/setup-local-ai.sh" "setup-local-ai"
install_script "$RAYCAST_DIR/generate-sakurajima-commands.sh" "generate-sakurajima-commands"

# Time tracking scripts
install_script "$SCRIPTS_DIR/sakurajima-time-init.sh" "sakurajima-time-init"
install_script "$SCRIPTS_DIR/sakurajima-time-start.sh" "sakurajima-time-start"
install_script "$SCRIPTS_DIR/sakurajima-time-cleanup.sh" "sakurajima-time-cleanup"
install_script "$SCRIPTS_DIR/sakurajima-time-tracker-daemon.sh" "sakurajima-time-tracker-daemon"
install_script "$SCRIPTS_DIR/sakurajima-unfocus.sh" "sakurajima-unfocus"
install_script "$SCRIPTS_DIR/sakurajima-stats.sh" "sakurajima-stats"

# Native shortcuts bridge commands (FIX)
install_script "$SCRIPTS_DIR/install-aerospace-native-shortcuts.sh" "install-aerospace-native-shortcuts"
install_script "$SCRIPTS_DIR/update-aerospace-native-shortcuts.sh" "update-aerospace-native-shortcuts"

# Generated artifacts
generate-aerospace-config
generate-sakurajima-commands

# Safe defaults (idempotent)
macos-defaults || warn "macos-defaults had warnings (non-fatal)"

# Local AI Setup
info "Setting up Local AI..."
setup-local-ai

# SketchyBar service
if command_exists sketchybar; then
  brew services start sketchybar || true
  sketchybar --reload || true
else
  warn "sketchybar not found; skipping service start"
fi

# Reload AeroSpace (if available)
if command_exists aerospace; then
  aerospace reload-config || true
fi

# Install/refresh native shortcuts bridge
if command_exists install-aerospace-native-shortcuts; then
  install-aerospace-native-shortcuts || warn "Native shortcuts installer had warnings"
fi

# Final gate
verify-system || die "Verification failed"

# --- BROWSER DEV INFRA (depot_tools) ---
DEPOT_TOOLS="$WORKSPACE/depot_tools"
if [[ ! -d "$DEPOT_TOOLS" ]]; then
  info "Cloning depot_tools (Chromium/WebKit prerequisite)..."
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS"
else
  ok "depot_tools exists"
fi
export PATH="$DEPOT_TOOLS:$PATH"

# --- SAKURAJIMA CLIENTS ---
info "Provisioning default clients (Chromium & WebKit)…"
G_NAME="$(git config --global user.name || true)"
[[ -n "$G_NAME" ]] || G_NAME="Chrome Dev"

G_EMAIL="$(git config --global user.email || true)"
[[ -n "$G_EMAIL" ]] || G_EMAIL="dev@chromium.local"

if [[ ! -d "$CLIENTS/chromium" ]]; then
  "$LOCAL_BIN/new-client" chromium --name "$G_NAME" --email "$G_EMAIL" --no-clipboard
else
  ok "Client 'chromium' exists"
fi

if [[ ! -d "$CLIENTS/webkit" ]]; then
  "$LOCAL_BIN/new-client" webkit --name "$G_NAME" --email "$G_EMAIL" --no-clipboard
else
  ok "Client 'webkit' exists"
fi

generate-aerospace-config
generate-sakurajima-commands

if command_exists aerospace; then
  aerospace reload-config || true
fi

if command_exists sketchybar; then
  sketchybar --reload || true
fi

bold "✅ INSTALL COMPLETE"
info "macOS 26+: bind the 14 window shortcuts in Shortcuts.app using:"
info "  ~/.local/share/sakurajima/aerospace-actions/SHORTCUTS_MAP.txt"

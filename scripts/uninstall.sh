#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
info(){ printf "ℹ️  %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }

# Targeted files for removal
BINARIES=(
  "skr"
  "verify-system"
  "new-client"
  "generate-aerospace-config"
  "update-aerospace"
  "sakurajima-confirm"
  "kubectl-guard"
  "terraform-guard"
  "update-all"
  "macos-defaults"
  "sakurajima-infra-up"
  "sakurajima-infra-down"
  "sakurajima-infra-backup"
  "sakurajima-logo"
  "generate-sakurajima-commands"
  "uninstall"
)

SYMLINKS=(
  "$HOME/.zshrc"
  "$HOME/.config/starship.toml"
  "$HOME/.config/aerospace.toml"
)

# .gitconfig is copied (not symlinked), handle separately
GITCONFIG_FILES=(
  "$HOME/.gitconfig"
  "$HOME/.gitconfig.local"
)

RAYCAST_DIR="$HOME/raycast/scripts/sakurajima"

echo
bold "🗑  SAKURAJIMA UNINSTALLER"
echo "This will remove:"
echo "  1. Installed scripts in ~/.local/bin"
echo "  2. Config symlinks (.zshrc, aerospace.toml, starship.toml)"
echo "  3. Generated Raycast scripts"
echo
warn "NOTE: .gitconfig and .gitconfig.local will NOT be removed (they contain your personal config)"
echo "      Remove them manually if desired: rm ~/.gitconfig ~/.gitconfig.local"
echo

echo "Type 'yes' to continue:"
read -r confirmation
if [[ "$confirmation" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

info "Removing binaries..."
for bin in "${BINARIES[@]}"; do
  file="$HOME/.local/bin/$bin"
  if [[ -f "$file" ]]; then
    rm "$file"
    echo "  Removed: $file"
  else
    echo "  Missing: $file (skipped)"
  fi
done

info "Removing config symlinks..."
for link in "${SYMLINKS[@]}"; do
  if [[ -L "$link" || -f "$link" ]]; then
    rm "$link"
    echo "  Removed: $link"
  else
    echo "  Missing: $link (skipped)"
  fi
done

info "Removing Raycast scripts..."
if [[ -d "$RAYCAST_DIR" ]]; then
  rm -rf "$RAYCAST_DIR"
  echo "  Removed: $RAYCAST_DIR"
else
  echo "  Missing: $RAYCAST_DIR (skipped)"
fi

echo
ok "Uninstall complete."
echo "You may need to restart your shell to reset behavior (like prompt)."

#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

info(){ printf "ℹ️  %s\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*"; }

# Some settings require logout/restart to fully apply.
# We apply safe defaults only.

info "Applying macOS defaults (safe subset)…"

# Create screenshot folder
SCREENSHOT_DIR="${HOME}/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: default search scope to current folder
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Finder: avoid .DS_Store on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Dock: speed up animations
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock autohide-delay -float 0.0
defaults write com.apple.dock autohide-time-modifier -float 0.1

# Keyboard: faster repeat (may be limited by managed profiles)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Trackpad: tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Screenshots: location and format
defaults write com.apple.screencapture location -string "$SCREENSHOT_DIR"
defaults write com.apple.screencapture type -string "png"

# Reduce accidental “smart quotes/dashes” in coding contexts
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable Spotlight shortcuts (conflicts with Raycast)
# 64: Cmd+Space (Select Input Source / Spotlight) - Disable
defaults write com.apple.Symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{enabled = 0; value = {parameters = (65535, 49, 1048576); type = 'standard';};}"
# 65: Cmd+Opt+Space (Finder Search) - Disable
defaults write com.apple.Symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{enabled = 0; value = {parameters = (65535, 49, 1572864); type = 'standard';};}"

# Disable Spotlight Indexing (requires sudo)
info "Disabling Spotlight indexing..."
sudo -n mdutil -i off / >/dev/null 2>&1 || warn "Could not disable Spotlight (sudo required). Run 'sudo mdutil -i off /' manually."

# Apply changes
killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

ok "macOS defaults applied (safe subset)."
warn "Some settings may require logout/reboot or may be blocked by MDM."

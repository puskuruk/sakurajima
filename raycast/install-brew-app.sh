#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Install Homebrew App
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima

# Optional parameters:
# @raycast.icon 🍺
# @raycast.argument1 { "type": "text", "placeholder": "App name (e.g., obsidian, slack)" }

# Documentation:
# @raycast.description Install a macOS application via Homebrew from the catalog
# @raycast.author Puskuruk
# @raycast.authorURL https://github.com/puskuruk

set -Eeuo pipefail

APP_NAME="$1"
CATALOG="$HOME/setup/configs/apps-catalog.json"

if [[ ! -f "$CATALOG" ]]; then
  echo "❌ App catalog not found at $CATALOG"
  exit 1
fi

# Find the app in catalog
APP_DATA=$(jq -r --arg name "$APP_NAME" '.homebrew[] | select(.slug == $name)' "$CATALOG")

if [[ -z "$APP_DATA" ]]; then
  echo "❌ App '$APP_NAME' not found in catalog"
  echo ""
  echo "Available Homebrew apps:"
  jq -r '.homebrew[] | "  • \(.slug) - \(.description)"' "$CATALOG"
  exit 1
fi

# Extract app details
CASK=$(echo "$APP_DATA" | jq -r '.cask')
DESCRIPTION=$(echo "$APP_DATA" | jq -r '.description')
NAME=$(echo "$APP_DATA" | jq -r '.name')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🍺 Installing: $NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 $DESCRIPTION"
echo "📦 Cask: $CASK"
echo ""

# Check if already installed
echo "[1/2] 🔍 Checking installation status..."
if brew list --cask "$CASK" >/dev/null 2>&1; then
  echo "      ✓ Already installed, will upgrade if needed"
else
  echo "      ✓ Not installed, proceeding with fresh install"
fi
echo ""

# Install via Homebrew
echo "[2/2] 🚀 Installing via Homebrew..."
echo ""

if brew install --cask "$CASK"; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Successfully installed $NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "📋 App location: /Applications/$NAME.app"
  echo "💡 Launch $NAME from your Applications folder"
else
  echo ""
  echo "❌ Installation failed"
  echo ""
  echo "💡 This might be because:"
  echo "  • The app is already installed (check /Applications)"
  echo "  • You need to approve security permissions in System Preferences"
  echo "  • The cask name has changed (run: brew search $APP_NAME)"
  exit 1
fi

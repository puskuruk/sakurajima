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

echo "🍺 Installing: $NAME"
echo "📝 $DESCRIPTION"
echo "📦 Cask: $CASK"
echo ""
echo "🚀 Running installation..."
echo ""

# Install via Homebrew
if brew install --cask "$CASK"; then
  echo ""
  echo "✅ Successfully installed $NAME"
  echo ""
  echo "You can now find $NAME in your Applications folder"
else
  echo ""
  echo "❌ Installation failed"
  echo ""
  echo "This might be because:"
  echo "  • The app is already installed"
  echo "  • You need to approve security permissions"
  echo "  • The cask name has changed"
  exit 1
fi

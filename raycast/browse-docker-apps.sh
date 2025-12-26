#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Browse Docker Apps
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima

# Optional parameters:
# @raycast.icon 🐳

# Documentation:
# @raycast.description Browse available Docker applications from the catalog
# @raycast.author Puskuruk
# @raycast.authorURL https://github.com/puskuruk

set -Eeuo pipefail

CATALOG="$HOME/setup/configs/apps-catalog.json"

if [[ ! -f "$CATALOG" ]]; then
  echo "❌ App catalog not found at $CATALOG"
  exit 1
fi

echo "🐳 DOCKER APPLICATIONS CATALOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Group by category
CATEGORIES=$(jq -r '.docker[].category' "$CATALOG" | sort -u)

while IFS= read -r category; do
  echo "📁 $(echo "$category" | tr '[:lower:]' '[:upper:]')"
  echo ""

  jq -r --arg cat "$category" '.docker[] | select(.category == $cat) |
    "  🔹 \(.slug)\n     \(.description)\n     Image: \(.image)\n     " +
    (if .port then "Ports: \(.port)" else "" end)' "$CATALOG"

  echo ""
done <<< "$CATEGORIES"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To install an app, use:"
echo "  Raycast → Install Docker App → <app-slug>"
echo ""
echo "Example: postgres, redis, mongodb, etc."

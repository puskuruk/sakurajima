#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Install Docker App
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima

# Optional parameters:
# @raycast.icon 🐳
# @raycast.argument1 { "type": "text", "placeholder": "App name (e.g., postgres, redis)" }

# Documentation:
# @raycast.description Install and run a Docker container from the app catalog
# @raycast.author Puskuruk
# @raycast.authorURL https://github.com/puskuruk

set -Eeuo pipefail

APP_NAME="$1"
CATALOG="$HOME/setup/configs/apps-catalog.json"
DOCKER_INSTALL="$HOME/setup/scripts/docker-install.sh"

if [[ ! -f "$CATALOG" ]]; then
  echo "❌ App catalog not found at $CATALOG"
  exit 1
fi

if [[ ! -f "$DOCKER_INSTALL" ]]; then
  echo "❌ docker-install.sh not found at $DOCKER_INSTALL"
  exit 1
fi

# Find the app in catalog
APP_DATA=$(jq -r --arg name "$APP_NAME" '.docker[] | select(.slug == $name)' "$CATALOG")

if [[ -z "$APP_DATA" ]]; then
  echo "❌ App '$APP_NAME' not found in catalog"
  echo ""
  echo "Available Docker apps:"
  jq -r '.docker[] | "  • \(.slug) - \(.description)"' "$CATALOG"
  exit 1
fi

# Extract app details
IMAGE=$(echo "$APP_DATA" | jq -r '.image')
DESCRIPTION=$(echo "$APP_DATA" | jq -r '.description')
PORTS=$(echo "$APP_DATA" | jq -r '.port // empty')
ENVS=$(echo "$APP_DATA" | jq -r '.env[]? // empty')
VOLUME=$(echo "$APP_DATA" | jq -r '.volume // empty')
COMMAND=$(echo "$APP_DATA" | jq -r '.command // empty')

echo "🐳 Installing: $DESCRIPTION"
echo "📦 Image: $IMAGE"
echo ""

# Build docker-install command
CMD=("$DOCKER_INSTALL" "$IMAGE" "--run" "--name" "sakurajima-$APP_NAME")

# Add ports
if [[ -n "$PORTS" ]]; then
  IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
  for port in "${PORT_ARRAY[@]}"; do
    CMD+=("-p" "$port")
  done
fi

# Add environment variables
if [[ -n "$ENVS" ]]; then
  while IFS= read -r env; do
    [[ -n "$env" ]] && CMD+=("-e" "$env")
  done <<< "$ENVS"
fi

# Add volume
if [[ -n "$VOLUME" ]]; then
  # Expand tilde in volume path
  VOLUME_EXPANDED="${VOLUME/#\~/$HOME}"
  # Create host directory if it doesn't exist
  HOST_DIR="${VOLUME_EXPANDED%%:*}"
  mkdir -p "$HOST_DIR"
  CMD+=("-v" "$VOLUME_EXPANDED")
fi

echo "🚀 Running installation..."
echo ""

# Execute installation
if "${CMD[@]}"; then
  echo ""
  echo "✅ Successfully installed $APP_NAME"
  echo ""
  echo "📝 Container name: sakurajima-$APP_NAME"
  [[ -n "$PORTS" ]] && echo "🌐 Ports: $PORTS"
  [[ -n "$VOLUME" ]] && echo "💾 Data: $HOST_DIR"
  echo ""
  echo "Manage with: docker ps | docker logs sakurajima-$APP_NAME"
else
  echo ""
  echo "❌ Installation failed"
  exit 1
fi

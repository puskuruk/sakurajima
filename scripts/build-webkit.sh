#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🦁 SAKURAJIMA WEBKIT BUILDER

info(){ printf "ℹ️  %s\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*"; }
die(){ printf "❌ %s\n" "$*"; exit "${2:-1}"; }

CLIENT_DIR="$HOME/workspace/clients/webkit"

# Ensure directory exists
if [[ ! -d "$CLIENT_DIR" ]]; then
  mkdir -p "$CLIENT_DIR"
fi

# Clone if empty
if [[ -z "$(ls -A "$CLIENT_DIR")" ]]; then
  info "Cloning WebKit into $CLIENT_DIR..."
  info "repo: https://github.com/WebKit/WebKit.git"
  git clone https://github.com/WebKit/WebKit.git "$CLIENT_DIR"
else
  info "WebKit directory not empty, skipping clone."
fi

cd "$CLIENT_DIR"

# Verify build script exists
if [[ ! -x "Tools/Scripts/build-webkit" ]]; then
  die "Build script Tools/Scripts/build-webkit not found/executable."
fi

info "Starting WebKit build (Release)..."
info "This will take HOURS. Go grab another coffee ☕."

./Tools/Scripts/build-webkit --release

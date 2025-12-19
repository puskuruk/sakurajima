#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🏴 SAKURAJIMA INFRA UP - 0.1.0-alpha

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
info(){ printf "ℹ️  %s\n" "$*"; }

SETUP_DIR="$HOME/setup"
DOCKER_COMPOSE="$SETUP_DIR/infra/docker-compose.yml"
DATA_DIR="$HOME/workspace/data"

bold "🚀 SAKURAJIMA INFRA: START"

if [[ ! -f "$DOCKER_COMPOSE" ]]; then
  echo "❌ Missing docker-compose.yml at $DOCKER_COMPOSE" >&2
  exit 1
fi

export SAKURAJIMA_DATA_DIR="$DATA_DIR"
mkdir -p "$DATA_DIR"

info "Starting containers..."
docker compose -f "$DOCKER_COMPOSE" up -d

echo
bold "✅ INFRASTRUCTURE RUNNING"
docker compose -f "$DOCKER_COMPOSE" ps

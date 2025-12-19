#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🏴 SAKURAJIMA INFRA DOWN - 0.1.0-alpha

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
info(){ printf "ℹ️  %s\n" "$*"; }

SETUP_DIR="$HOME/setup"
DOCKER_COMPOSE="$SETUP_DIR/infra/docker-compose.yml"
DATA_DIR="$HOME/workspace/data"

bold "🛑 SAKURAJIMA INFRA: STOP"

export SAKURAJIMA_DATA_DIR="$DATA_DIR"

if [[ -f "$DOCKER_COMPOSE" ]]; then
  docker compose -f "$DOCKER_COMPOSE" stop
  bold "✅ Stopped."
else
  echo "⚠️  docker-compose.yml not found."
fi

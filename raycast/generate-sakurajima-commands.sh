#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🏴 SAKURAJIMA RAYCAST GENERATOR - 0.1.0-alpha

TARGET="${HOME}/raycast/scripts/sakurajima"
CLIENTS_DIR="${HOME}/workspace/clients"

mkdir -p "$TARGET"

# Discover clients
mapfile -t clients < <(
  [[ -d "$CLIENTS_DIR" ]] && find "$CLIENTS_DIR" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null \
    | sed "s|^${CLIENTS_DIR}/||" \
    | grep -vE '^(_archive|\.)' \
    | LC_ALL=C sort || true
)

write_script() {
  local path="$1"
  shift
  cat > "$path" <<EOF
$*
EOF
  chmod +x "$path"
}

# sakurajima-verify
write_script "$TARGET/sakurajima-verify.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Verify System
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon ✅
# @raycast.description Runs verify-system (aggressive checks)

set -Eeuo pipefail
IFS=$'\''\n\t'\''
export PATH="$HOME/.local/bin:$PATH"

exec verify-system
'

# sakurajima-update-aerospace
write_script "$TARGET/sakurajima-update-aerospace.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Update AeroSpace
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 🪟
# @raycast.description Regenerates and reloads AeroSpace config from clients

set -Eeuo pipefail
IFS=$'\''\n\t'\''
export PATH="$HOME/.local/bin:$PATH"

exec update-aerospace
'

# sakurajima-open-terminal
write_script "$TARGET/sakurajima-open-terminal.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Open Terminal
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 🖥️
# @raycast.description Opens Terminal with a fresh shell in the default directory

set -Eeuo pipefail
IFS=$'\''\n\t'\''

osascript <<OSA
tell application "Terminal"
  activate
  do script ""
end tell
OSA
'

# sakurajima-infra-up
write_script "$TARGET/sakurajima-infra-up.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Infra Up
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 🐳
# @raycast.description Starts docker compose infra (mongo/postgres/redis)

set -Eeuo pipefail
IFS=$'\''\n\t'\''
export PATH="$HOME/.local/bin:$PATH"

exec sakurajima-infra-up
'

# sakurajima-infra-down
write_script "$TARGET/sakurajima-infra-down.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Infra Down
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 🧹
# @raycast.description Stops docker compose infra

set -Eeuo pipefail
IFS=$'\''\n\t'\''
export PATH="$HOME/.local/bin:$PATH"

exec sakurajima-infra-down
'

# sakurajima-docker-status
write_script "$TARGET/sakurajima-docker-status.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Docker Status
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima
# @raycast.icon 📊
# @raycast.description Shows running Docker containers and resource usage

set -Eeuo pipefail
IFS=$'\''\n\t'\''

echo "🐳 RUNNING CONTAINERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"
echo
echo "📊 RESOURCE USAGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || true
echo
echo "💾 DISK USAGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker system df 2>/dev/null || true
'

# sakurajima-docker-restart
write_script "$TARGET/sakurajima-docker-restart.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Docker Restart Infra
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 🔄
# @raycast.description Restarts all docker compose infra containers

set -Eeuo pipefail
IFS=$'\''\n\t'\''
export PATH="$HOME/.local/bin:$PATH"

DOCKER_COMPOSE="$HOME/setup/infra/docker-compose.yml"
export SAKURAJIMA_DATA_DIR="$HOME/workspace/data"

docker compose -f "$DOCKER_COMPOSE" restart
echo "✅ Infrastructure restarted"
'

# sakurajima-lazydocker (TUI - Omarchy style)
write_script "$TARGET/sakurajima-lazydocker.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Lazydocker
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 🦥
# @raycast.description Opens Lazydocker TUI for container management (Omarchy Super+Shift+D)

set -Eeuo pipefail
IFS=$'\''\n\t'\''

# Open Terminal with lazydocker
osascript <<OSA
tell application "Terminal"
  activate
  do script "lazydocker"
end tell
OSA
'

# sakurajima-docker-logs
write_script "$TARGET/sakurajima-docker-logs.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Docker Logs
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 📜
# @raycast.description Opens Terminal with docker compose logs (follow mode)

set -Eeuo pipefail
IFS=$'\''\n\t'\''

DOCKER_COMPOSE="$HOME/setup/infra/docker-compose.yml"
export SAKURAJIMA_DATA_DIR="$HOME/workspace/data"

osascript <<OSA
tell application "Terminal"
  activate
  do script "SAKURAJIMA_DATA_DIR=\"$HOME/workspace/data\" docker compose -f \"$HOME/setup/infra/docker-compose.yml\" logs -f"
end tell
OSA
'

# sakurajima-docker-prune
write_script "$TARGET/sakurajima-docker-prune.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Docker Prune
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima
# @raycast.icon 🗑️
# @raycast.description Cleans up unused Docker resources (containers, images, volumes)

set -Eeuo pipefail
IFS=$'\''\n\t'\''

echo "🧹 DOCKER SYSTEM PRUNE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "Before:"
docker system df

echo
docker system prune -f

echo
echo "After:"
docker system df

echo
echo "✅ Docker cleanup complete"
'

# sakurajima-docker-install (with autocomplete)
write_script "$TARGET/sakurajima-docker-install.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Docker Install Image
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima
# @raycast.icon 📦
# @raycast.description Pull and optionally run any Docker image with autocomplete
# @raycast.argument1 { "type": "text", "placeholder": "image (e.g., postgres, mongo:7)" }
# @raycast.argument2 { "type": "text", "placeholder": "options: --run -p PORT", "optional": true }

set -Eeuo pipefail
IFS=$'\''\\n\\t'\''
export PATH="$HOME/.local/bin:$PATH"

IMAGE="${1:-}"
OPTIONS="${2:-}"

if [[ -z "$IMAGE" ]]; then
  echo "❌ Image name required"
  exit 1
fi

echo "🐳 DOCKER INSTALL: $IMAGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Pull the image
echo "📥 Pulling image..."
if docker pull "$IMAGE"; then
  echo "✅ Image pulled successfully"
else
  echo "❌ Failed to pull image"
  exit 1
fi

# If --run is in options, start container
if [[ "$OPTIONS" == *"--run"* ]]; then
  echo
  CONTAINER_NAME="sakurajima-$(echo "$IMAGE" | sed '\''s|.*/||'\'' | sed '\''s|:.*||'\'' | tr '\''/'\'' '\''-'\'')"
  
  # Extract port if specified
  PORT_ARGS=""
  if [[ "$OPTIONS" =~ -p[[:space:]]+([0-9:]+) ]]; then
    PORT_ARGS="-p ${BASH_REMATCH[1]}"
  fi
  
  echo "🚀 Starting container: $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  
  # shellcheck disable=SC2086
  if docker run -d --name "$CONTAINER_NAME" --restart unless-stopped $PORT_ARGS "$IMAGE"; then
    echo "✅ Container started"
    echo
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"
  else
    echo "❌ Failed to start container"
    exit 1
  fi
fi

echo
echo "✅ Done!"
'

# Generate autocomplete data file for Raycast
AUTOCOMPLETE_FILE="$TARGET/_docker-images-autocomplete.json"
cat > "$AUTOCOMPLETE_FILE" << 'AUTOCOMPLETE'
{
  "images": [
    {"name": "postgres", "description": "PostgreSQL database"},
    {"name": "postgres:16", "description": "PostgreSQL 16"},
    {"name": "postgres:15", "description": "PostgreSQL 15"},
    {"name": "mongo", "description": "MongoDB database"},
    {"name": "mongo:7", "description": "MongoDB 7"},
    {"name": "mongo:6", "description": "MongoDB 6"},
    {"name": "mysql", "description": "MySQL database"},
    {"name": "mysql:8", "description": "MySQL 8"},
    {"name": "mariadb", "description": "MariaDB database"},
    {"name": "redis", "description": "Redis in-memory store"},
    {"name": "redis:7", "description": "Redis 7"},
    {"name": "memcached", "description": "Memcached"},
    {"name": "elasticsearch", "description": "Elasticsearch"},
    {"name": "neo4j", "description": "Neo4j graph database"},
    {"name": "influxdb", "description": "InfluxDB time-series"},
    {"name": "clickhouse/clickhouse-server", "description": "ClickHouse analytics"},
    {"name": "rabbitmq", "description": "RabbitMQ message broker"},
    {"name": "rabbitmq:management", "description": "RabbitMQ with UI"},
    {"name": "nats", "description": "NATS messaging"},
    {"name": "eclipse-mosquitto", "description": "Mosquitto MQTT"},
    {"name": "nginx", "description": "NGINX web server"},
    {"name": "nginx:alpine", "description": "NGINX Alpine"},
    {"name": "httpd", "description": "Apache HTTP"},
    {"name": "traefik", "description": "Traefik proxy"},
    {"name": "caddy", "description": "Caddy server"},
    {"name": "haproxy", "description": "HAProxy"},
    {"name": "node", "description": "Node.js"},
    {"name": "node:20", "description": "Node.js 20 LTS"},
    {"name": "node:22", "description": "Node.js 22"},
    {"name": "node:20-alpine", "description": "Node.js 20 Alpine"},
    {"name": "python", "description": "Python"},
    {"name": "python:3.12", "description": "Python 3.12"},
    {"name": "python:3.11", "description": "Python 3.11"},
    {"name": "golang", "description": "Go language"},
    {"name": "golang:1.22", "description": "Go 1.22"},
    {"name": "ruby", "description": "Ruby"},
    {"name": "php", "description": "PHP"},
    {"name": "openjdk", "description": "OpenJDK"},
    {"name": "eclipse-temurin:21", "description": "Temurin JDK 21"},
    {"name": "rust", "description": "Rust"},
    {"name": "elixir", "description": "Elixir"},
    {"name": "jenkins/jenkins", "description": "Jenkins CI"},
    {"name": "gitlab/gitlab-ce", "description": "GitLab CE"},
    {"name": "gitea/gitea", "description": "Gitea"},
    {"name": "sonarqube", "description": "SonarQube"},
    {"name": "vault", "description": "HashiCorp Vault"},
    {"name": "consul", "description": "HashiCorp Consul"},
    {"name": "localstack/localstack", "description": "LocalStack AWS"},
    {"name": "minio/minio", "description": "MinIO storage"},
    {"name": "registry", "description": "Docker Registry"},
    {"name": "portainer/portainer-ce", "description": "Portainer"},
    {"name": "grafana/grafana", "description": "Grafana"},
    {"name": "prom/prometheus", "description": "Prometheus"},
    {"name": "jaegertracing/all-in-one", "description": "Jaeger tracing"},
    {"name": "ollama/ollama", "description": "Ollama AI"},
    {"name": "alpine", "description": "Alpine Linux"},
    {"name": "ubuntu", "description": "Ubuntu"},
    {"name": "ubuntu:24.04", "description": "Ubuntu 24.04"},
    {"name": "debian", "description": "Debian"},
    {"name": "busybox", "description": "BusyBox"}
  ]
}
AUTOCOMPLETE

# sakurajima-docker-list-images (show available images for autocomplete reference)
write_script "$TARGET/sakurajima-docker-images-list.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Docker Images List
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima
# @raycast.icon 📋
# @raycast.description Shows available official Docker images for quick reference

echo "📦 OFFICIAL DOCKER IMAGES (Quick Reference)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "🗄️  DATABASES"
echo "   postgres, postgres:16, postgres:15"
echo "   mongo, mongo:7, mongo:6"  
echo "   mysql, mysql:8, mariadb"
echo "   redis, redis:7, memcached"
echo "   elasticsearch, neo4j, influxdb"
echo "   clickhouse/clickhouse-server"
echo
echo "📨 MESSAGE QUEUES"
echo "   rabbitmq, rabbitmq:management"
echo "   nats, eclipse-mosquitto"
echo
echo "🌐 WEB SERVERS"
echo "   nginx, nginx:alpine, httpd"
echo "   traefik, caddy, haproxy"
echo
echo "⚡ LANGUAGES/RUNTIMES"
echo "   node, node:20, node:22, node:20-alpine"
echo "   python, python:3.12, python:3.11"
echo "   golang, golang:1.22, ruby, php"
echo "   openjdk, eclipse-temurin:21, rust"
echo
echo "🔧 DEVOPS/TOOLS"
echo "   jenkins/jenkins, gitlab/gitlab-ce, gitea/gitea"
echo "   sonarqube, vault, consul"
echo "   localstack/localstack, minio/minio"
echo "   portainer/portainer-ce, registry"
echo
echo "📊 MONITORING"
echo "   grafana/grafana, prom/prometheus"
echo "   jaegertracing/all-in-one"
echo
echo "🤖 AI/ML"
echo "   ollama/ollama"
echo
echo "🐧 BASE IMAGES"
echo "   alpine, ubuntu, ubuntu:24.04, debian, busybox"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Use '\''Sakurajima: Docker Install Image'\'' to pull any of these"
'

write_script "$TARGET/_sakurajima-focus-lib.sh" \
'#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\''\n\t'\''

focus_client() {
  local client="$1"
  local dir="${HOME}/workspace/clients/${client}"

  # 1. Try exact match
  if [[ ! -d "$dir" ]]; then
      # 2. Try removing dashes (web-kit -> webkit)
      local nodash="${client//-/}"
      local dir_nodash="${HOME}/workspace/clients/${nodash}"

      if [[ -d "$dir_nodash" ]]; then
          dir="$dir_nodash"
          client="$nodash"
      else
          echo "❌ Missing client dir: $dir (and $dir_nodash)" >&2; exit 2;
      fi
  fi

  # Start time tracking (non-blocking, do not fail if tracking fails)
  if command -v sakurajima-time-start >/dev/null 2>&1; then
      sakurajima-time-start "$client" || true
  fi

  # Prefer iTerm if installed? We stay deterministic: use macOS Terminal.
  osascript <<OSA
tell application "Terminal"
  activate
  do script "cd ${dir}"
end tell
OSA
}
'

# sakurajima-focus-client (argument prompt)
write_script "$TARGET/sakurajima-focus-client.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Focus Client
# @raycast.mode fullOutput
# @raycast.packageName Sakurajima
# @raycast.icon 🎯
# @raycast.description Choose a client and open Terminal in it
# @raycast.argument1 { "type": "text", "placeholder": "client (kebab-case)" }

set -Eeuo pipefail
IFS=$'\''\n\t'\''

client="${1:-}"
[[ -n "$client" ]] || { echo "Provide a client name."; exit 2; }

source "$(dirname "$0")/_sakurajima-focus-lib.sh"
focus_client "$client"
echo "✅ Focused: $client"
'

# Per-client direct scripts
for c in "${clients[@]}"; do
  script="$TARGET/sakurajima-focus-${c}.sh"
  write_script "$script" \
"#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Focus ${c}
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon 🎯
# @raycast.description Open Terminal in ~/workspace/clients/${c}

set -Eeuo pipefail
IFS=$'\\n\\t'

source \"\$(dirname \"\$0\")/_sakurajima-focus-lib.sh\"
focus_client \"${c}\"
"
done

# sakurajima-unfocus (stop time tracking)
write_script "$TARGET/sakurajima-unfocus.sh" \
'#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sakurajima: Unfocus (Stop Timer)
# @raycast.mode silent
# @raycast.packageName Sakurajima
# @raycast.icon ⏹️
# @raycast.description Stop current time tracking session

set -Eeuo pipefail
export PATH="$HOME/.local/bin:$PATH"

exec sakurajima-unfocus
'

echo "✅ Raycast scripts generated in: $TARGET"
echo "ℹ️  Clients: ${#clients[@]}"

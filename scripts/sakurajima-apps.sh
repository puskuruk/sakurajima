#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Sakurajima Apps - Omakub-style application installer
# Manages Docker containers and Homebrew applications from a central catalog

CATALOG="$HOME/setup/configs/apps-catalog.json"
DOCKER_INSTALL="$HOME/setup/scripts/docker-install.sh"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "ℹ️  %s\n" "$*"; }
ok() { printf "✅ %s\n" "$*"; }
error() { printf "❌ %s\n" "$*" >&2; }

usage() {
  cat << 'EOF'
Sakurajima Apps - Application Installation Manager

Usage: sakurajima-apps <command> [options]

Commands:
  list docker          List all available Docker applications
  list brew            List all available Homebrew applications
  list all             List all applications

  install docker <app> Install a Docker application
  install brew <app>   Install a Homebrew application

  search <query>       Search for applications
  info <app>           Show detailed information about an app

  running              Show running Docker containers
  stop <app>           Stop a Docker container
  remove <app>         Remove a Docker container
  logs <app>           Show logs for a Docker container

Examples:
  sakurajima-apps list docker
  sakurajima-apps install docker postgres
  sakurajima-apps install brew obsidian
  sakurajima-apps search database
  sakurajima-apps running

EOF
  exit 0
}

check_catalog() {
  if [[ ! -f "$CATALOG" ]]; then
    error "App catalog not found at $CATALOG"
    exit 1
  fi
}

list_docker_apps() {
  check_catalog
  echo ""
  bold "🐳 DOCKER APPLICATIONS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  CATEGORIES=$(jq -r '.docker[].category' "$CATALOG" | sort -u)

  while IFS= read -r category; do
    echo ""
    echo "📁 $(echo "$category" | tr '[:lower:]' '[:upper:]')"
    jq -r --arg cat "$category" '.docker[] | select(.category == $cat) |
      "  • \(.slug) - \(.description)"' "$CATALOG"
  done <<< "$CATEGORIES"
  echo ""
}

list_brew_apps() {
  check_catalog
  echo ""
  bold "🍺 HOMEBREW APPLICATIONS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  CATEGORIES=$(jq -r '.homebrew[].category' "$CATALOG" | sort -u)

  while IFS= read -r category; do
    echo ""
    echo "📁 $(echo "$category" | tr '[:lower:]' '[:upper:]')"
    jq -r --arg cat "$category" '.homebrew[] | select(.category == $cat) |
      "  • \(.slug) - \(.description)"' "$CATALOG"
  done <<< "$CATEGORIES"
  echo ""
}

install_docker_app() {
  local app_name="$1"
  check_catalog

  APP_DATA=$(jq -r --arg name "$app_name" '.docker[] | select(.slug == $name)' "$CATALOG")

  if [[ -z "$APP_DATA" ]]; then
    error "App '$app_name' not found in Docker catalog"
    info "Run 'sakurajima-apps list docker' to see available apps"
    exit 1
  fi

  IMAGE=$(echo "$APP_DATA" | jq -r '.image')
  DESCRIPTION=$(echo "$APP_DATA" | jq -r '.description')
  PORTS=$(echo "$APP_DATA" | jq -r '.port // empty')
  ENVS=$(echo "$APP_DATA" | jq -r '.env[]? // empty')
  VOLUME=$(echo "$APP_DATA" | jq -r '.volume // empty')

  echo ""
  bold "🐳 Installing: $DESCRIPTION"
  info "Image: $IMAGE"
  echo ""

  CMD=("$DOCKER_INSTALL" "$IMAGE" "--run" "--name" "sakurajima-$app_name")

  if [[ -n "$PORTS" ]]; then
    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
    for port in "${PORT_ARRAY[@]}"; do
      CMD+=("-p" "$port")
    done
  fi

  if [[ -n "$ENVS" ]]; then
    while IFS= read -r env; do
      [[ -n "$env" ]] && CMD+=("-e" "$env")
    done <<< "$ENVS"
  fi

  if [[ -n "$VOLUME" ]]; then
    VOLUME_EXPANDED="${VOLUME/#\~/$HOME}"
    HOST_DIR="${VOLUME_EXPANDED%%:*}"
    mkdir -p "$HOST_DIR"
    CMD+=("-v" "$VOLUME_EXPANDED")
  fi

  if "${CMD[@]}"; then
    echo ""
    ok "Successfully installed $app_name"
    [[ -n "$PORTS" ]] && info "Ports: $PORTS"
    [[ -n "$VOLUME" ]] && info "Data: $HOST_DIR"
    echo ""
  else
    error "Installation failed"
    exit 1
  fi
}

install_brew_app() {
  local app_name="$1"
  check_catalog

  APP_DATA=$(jq -r --arg name "$app_name" '.homebrew[] | select(.slug == $name)' "$CATALOG")

  if [[ -z "$APP_DATA" ]]; then
    error "App '$app_name' not found in Homebrew catalog"
    info "Run 'sakurajima-apps list brew' to see available apps"
    exit 1
  fi

  CASK=$(echo "$APP_DATA" | jq -r '.cask')
  DESCRIPTION=$(echo "$APP_DATA" | jq -r '.description')
  NAME=$(echo "$APP_DATA" | jq -r '.name')

  echo ""
  bold "🍺 Installing: $NAME"
  info "$DESCRIPTION"
  echo ""

  if brew install --cask "$CASK"; then
    echo ""
    ok "Successfully installed $NAME"
  else
    error "Installation failed"
    exit 1
  fi
}

search_apps() {
  local query="$1"
  check_catalog

  echo ""
  bold "🔍 Search results for: $query"
  echo ""

  # Search Docker apps
  DOCKER_RESULTS=$(jq -r --arg q "$query" '.docker[] |
    select(.slug | contains($q) or .description | ascii_downcase | contains($q | ascii_downcase)) |
    "🐳 \(.slug) - \(.description)"' "$CATALOG")

  if [[ -n "$DOCKER_RESULTS" ]]; then
    echo "$DOCKER_RESULTS"
  fi

  # Search Homebrew apps
  BREW_RESULTS=$(jq -r --arg q "$query" '.homebrew[] |
    select(.slug | contains($q) or .description | ascii_downcase | contains($q | ascii_downcase)) |
    "🍺 \(.slug) - \(.description)"' "$CATALOG")

  if [[ -n "$BREW_RESULTS" ]]; then
    echo "$BREW_RESULTS"
  fi

  if [[ -z "$DOCKER_RESULTS" ]] && [[ -z "$BREW_RESULTS" ]]; then
    info "No apps found matching '$query'"
  fi
  echo ""
}

show_app_info() {
  local app_name="$1"
  check_catalog

  # Try to find in Docker apps first
  local docker_data=$(jq -r --arg name "$app_name" '.docker[] | select(.slug == $name)' "$CATALOG")

  if [[ -n "$docker_data" ]]; then
    echo ""
    bold "🐳 $(echo "$docker_data" | jq -r '.name')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Slug:        $app_name"
    echo "Type:        Docker Container"
    echo "Category:    $(echo "$docker_data" | jq -r '.category')"
    echo "Description: $(echo "$docker_data" | jq -r '.description')"
    echo "Image:       $(echo "$docker_data" | jq -r '.image')"

    local ports=$(echo "$docker_data" | jq -r '.port // empty')
    [[ -n "$ports" ]] && echo "Ports:       $ports"

    local volume=$(echo "$docker_data" | jq -r '.volume // empty')
    if [[ -n "$volume" ]]; then
      local expanded="${volume/#\~/$HOME}"
      echo "Data Volume: ${expanded%%:*}"
    fi

    local envs=$(echo "$docker_data" | jq -r '.env[]? // empty')
    if [[ -n "$envs" ]]; then
      echo ""
      echo "Environment Variables:"
      while IFS= read -r env; do
        [[ -n "$env" ]] && echo "  • $env"
      done <<< "$envs"
    fi

    # Check if running
    if docker ps --filter "name=sakurajima-$app_name" --format '{{.Names}}' | grep -q "sakurajima-$app_name"; then
      echo ""
      echo "Status:      ✅ Running"
      docker ps --filter "name=sakurajima-$app_name" --format "Uptime:      {{.Status}}"
    else
      echo ""
      echo "Status:      ⭕ Not running"
    fi

    echo ""
    echo "Install:     sakurajima-apps install docker $app_name"
    echo ""
    return 0
  fi

  # Try Homebrew apps
  local brew_data=$(jq -r --arg name "$app_name" '.homebrew[] | select(.slug == $name)' "$CATALOG")

  if [[ -n "$brew_data" ]]; then
    echo ""
    bold "🍺 $(echo "$brew_data" | jq -r '.name')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Slug:        $app_name"
    echo "Type:        Homebrew Cask"
    echo "Category:    $(echo "$brew_data" | jq -r '.category')"
    echo "Description: $(echo "$brew_data" | jq -r '.description')"
    echo "Cask:        $(echo "$brew_data" | jq -r '.cask')"

    # Check if installed
    local cask=$(echo "$brew_data" | jq -r '.cask')
    if brew list --cask "$cask" >/dev/null 2>&1; then
      echo ""
      echo "Status:      ✅ Installed"
    else
      echo ""
      echo "Status:      ⭕ Not installed"
    fi

    echo ""
    echo "Install:     sakurajima-apps install brew $app_name"
    echo ""
    return 0
  fi

  # App not found
  error "App '$app_name' not found in catalog"
  info "Run 'sakurajima-apps search $app_name' to find similar apps"
  echo ""
  return 1
}

show_running() {
  echo ""
  bold "🐳 Running Docker Containers"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  docker ps --filter "name=sakurajima-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  echo ""
}

stop_container() {
  local app_name="$1"
  docker stop "sakurajima-$app_name" && ok "Stopped $app_name" || error "Failed to stop $app_name"
}

remove_container() {
  local app_name="$1"
  docker rm -f "sakurajima-$app_name" && ok "Removed $app_name" || error "Failed to remove $app_name"
}

show_logs() {
  local app_name="$1"
  docker logs -f "sakurajima-$app_name"
}

# Main command router
case "${1:-}" in
  list)
    case "${2:-all}" in
      docker) list_docker_apps ;;
      brew) list_brew_apps ;;
      all) list_docker_apps; list_brew_apps ;;
      *) error "Unknown list type: $2"; usage ;;
    esac
    ;;

  install)
    case "${2:-}" in
      docker)
        [[ -z "${3:-}" ]] && error "App name required" && usage
        install_docker_app "$3"
        ;;
      brew)
        [[ -z "${3:-}" ]] && error "App name required" && usage
        install_brew_app "$3"
        ;;
      *) error "Unknown install type: ${2:-}"; usage ;;
    esac
    ;;

  search)
    [[ -z "${2:-}" ]] && error "Search query required" && usage
    search_apps "$2"
    ;;

  info)
    [[ -z "${2:-}" ]] && error "App name required" && usage
    show_app_info "$2"
    ;;

  running) show_running ;;
  stop)
    [[ -z "${2:-}" ]] && error "App name required" && usage
    stop_container "$2"
    ;;
  remove)
    [[ -z "${2:-}" ]] && error "App name required" && usage
    remove_container "$2"
    ;;
  logs)
    [[ -z "${2:-}" ]] && error "App name required" && usage
    show_logs "$2"
    ;;

  -h|--help|help) usage ;;
  *) error "Unknown command: ${1:-}"; usage ;;
esac

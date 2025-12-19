#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🏴 SAKURAJIMA DOCKER INSTALL - 0.1.0-alpha
# Pulls and optionally runs a Docker image

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
info(){ printf "ℹ️  %s\n" "$*"; }
error(){ printf "❌ %s\n" "$*" >&2; }

usage() {
  cat << EOF
Usage: docker-install <image>[:<tag>] [--run] [--name <container>] [--port <host:container>]

Arguments:
  image           Docker image name (e.g., postgres, mongo:7, nginx:alpine)
  
Options:
  --run           Start container after pulling
  --name          Container name (default: derived from image)
  --port, -p      Port mapping (can be used multiple times)
  --env, -e       Environment variable (can be used multiple times)
  --detach, -d    Run in detached mode (default: true)
  --volume, -v    Volume mount (can be used multiple times)

Examples:
  docker-install postgres
  docker-install mongo:7 --run --port 27017:27017
  docker-install redis --run -p 6379:6379 --name my-redis
EOF
  exit 1
}

# Parse arguments
IMAGE=""
RUN=false
CONTAINER_NAME=""
PORTS=()
ENVS=()
VOLUMES=()
DETACH=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run)
      RUN=true
      shift
      ;;
    --name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    -p|--port)
      PORTS+=("-p" "$2")
      shift 2
      ;;
    -e|--env)
      ENVS+=("-e" "$2")
      shift 2
      ;;
    -v|--volume)
      VOLUMES+=("-v" "$2")
      shift 2
      ;;
    -d|--detach)
      DETACH=true
      shift
      ;;
    --no-detach)
      DETACH=false
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      error "Unknown option: $1"
      usage
      ;;
    *)
      if [[ -z "$IMAGE" ]]; then
        IMAGE="$1"
      else
        error "Unexpected argument: $1"
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$IMAGE" ]]; then
  error "Image name required"
  usage
fi

# Derive container name from image if not provided
if [[ -z "$CONTAINER_NAME" ]]; then
  # Remove registry prefix and tag, replace / with -
  CONTAINER_NAME=$(echo "$IMAGE" | sed 's|.*/||' | sed 's|:.*||' | tr '/' '-')
  CONTAINER_NAME="sakurajima-${CONTAINER_NAME}"
fi

bold "🐳 DOCKER INSTALL: $IMAGE"
echo

# Pull the image
info "Pulling image..."
if docker pull "$IMAGE"; then
  echo "✅ Image pulled: $IMAGE"
else
  error "Failed to pull image: $IMAGE"
  exit 1
fi

# Run if requested
if [[ "$RUN" == true ]]; then
  echo
  info "Starting container: $CONTAINER_NAME"
  
  DOCKER_ARGS=()
  [[ "$DETACH" == true ]] && DOCKER_ARGS+=("-d")
  DOCKER_ARGS+=("--name" "$CONTAINER_NAME")
  DOCKER_ARGS+=("--restart" "unless-stopped")
  DOCKER_ARGS+=("${PORTS[@]}")
  DOCKER_ARGS+=("${ENVS[@]}")
  DOCKER_ARGS+=("${VOLUMES[@]}")
  DOCKER_ARGS+=("$IMAGE")
  
  # Remove existing container if exists
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  
  if docker run "${DOCKER_ARGS[@]}"; then
    echo "✅ Container started: $CONTAINER_NAME"
    echo
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  else
    error "Failed to start container"
    exit 1
  fi
fi

echo
bold "✅ DONE"

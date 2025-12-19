#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🏴 SAKURAJIMA INFRA BACKUP - 0.1.0-alpha

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
info(){ printf "ℹ️  %s\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }

BACKUP_ROOT="$HOME/workspace/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
TARGET="$BACKUP_ROOT/$TIMESTAMP"

bold "💾 SAKURAJIMA INFRA: BACKUP"

mkdir -p "$TARGET"
info "Destination: $TARGET"

# Mongo
info "Dumping Mongo..."
if docker compose -f ~/setup/infra/docker-compose.yml ps --services --filter "status=running" | grep -q mongo; then
  docker exec sakurajima-mongo mongodump --out /dump >/dev/null 2>&1
  docker cp sakurajima-mongo:/dump "$TARGET/mongo"
  ok "Mongo dumped"
else
  echo "⚠️  Mongo not running"
fi

# Postgres
info "Dumping Postgres..."
if docker compose -f ~/setup/infra/docker-compose.yml ps --services --filter "status=running" | grep -q postgres; then
  docker exec sakurajima-postgres pg_dumpall -U postgres > "$TARGET/postgres_dump.sql"
  ok "Postgres dumped"
else
  echo "⚠️  Postgres not running"
fi

bold "✅ BACKUP COMPLETE"
ls -lh "$TARGET"

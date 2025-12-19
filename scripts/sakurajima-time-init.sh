#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Initialize the Sakurajima time tracking database
# This script is idempotent - safe to run multiple times

CONFIG_DIR="${HOME}/.config/sakurajima"
DB="${CONFIG_DIR}/time-tracking.db"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Check if database already exists
if [[ -f "$DB" ]]; then
    echo "✅ Database already exists: $DB"
    exit 0
fi

# Create database with schema
sqlite3 "$DB" <<'SQL'
-- Sessions: One record per focus session
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    duration INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_sessions_client ON sessions(client);
CREATE INDEX idx_sessions_start_time ON sessions(start_time);
CREATE INDEX idx_sessions_active ON sessions(end_time) WHERE end_time IS NULL;

-- Applications: Deduplicated app names
CREATE TABLE applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    bundle_id TEXT
);

-- Application usage per session
CREATE TABLE app_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    application_id INTEGER NOT NULL,
    total_seconds INTEGER NOT NULL DEFAULT 0,
    last_seen INTEGER,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (application_id) REFERENCES applications(id),
    UNIQUE(session_id, application_id)
);

CREATE INDEX idx_app_usage_session ON app_usage(session_id);

-- Client metadata
CREATE TABLE clients (
    name TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
SQL

echo "✅ Time tracking database initialized: $DB"

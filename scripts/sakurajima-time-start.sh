#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Start a time tracking session for a client
# Arguments: CLIENT_NAME

# Source common library for sql_escape and validation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    # Fallback sql_escape if library not available
    sql_escape() { printf '%s' "${1//\'/\'\'}"; }
    validate_client_name() { [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; }
fi

NEW_CLIENT="${1:?Client name required}"
CONFIG_DIR="${HOME}/.config/sakurajima"
DB="${CONFIG_DIR}/time-tracking.db"
STATE_FILE="${CONFIG_DIR}/active-session.state"

# Validate client name to prevent injection
if ! validate_client_name "$NEW_CLIENT"; then
    echo "⚠️  Invalid client name: $NEW_CLIENT (must be kebab-case)" >&2
    exit 1
fi

# Initialize DB if needed
if [[ ! -f "$DB" ]]; then
    if command -v sakurajima-time-init >/dev/null 2>&1; then
        sakurajima-time-init
    else
        echo "⚠️  Database not initialized" >&2
        exit 1
    fi
fi

# Check for active session
if [[ -f "$STATE_FILE" ]]; then
    source "$STATE_FILE"
    OLD_CLIENT="${CLIENT:-unknown}"

    # Check if tracker process is still running
    if [[ -n "${TRACKER_PID:-}" ]] && kill -0 "$TRACKER_PID" 2>/dev/null; then
        if [[ "$NEW_CLIENT" == "$OLD_CLIENT" ]]; then
            echo "⚠️  Already tracking: $OLD_CLIENT"
            exit 0
        else
            echo "⚠️  Stopping previous session: $OLD_CLIENT"
            # Stop previous session
            if command -v sakurajima-unfocus >/dev/null 2>&1; then
                sakurajima-unfocus 2>/dev/null || true
            fi
        fi
    else
        # Stale session - clean up
        if command -v sakurajima-time-cleanup >/dev/null 2>&1; then
            sakurajima-time-cleanup 2>/dev/null || true
        else
            rm -f "$STATE_FILE"
        fi
    fi
fi

# Use NEW_CLIENT for the rest of the script
CLIENT="$NEW_CLIENT"

# Insert client if not exists (client name is validated above, safe to use)
ESCAPED_CLIENT="$(sql_escape "$CLIENT")"
if ! sqlite3 "$DB" "INSERT OR IGNORE INTO clients (name) VALUES ('${ESCAPED_CLIENT}');"; then
    echo "⚠️  Failed to insert client into database" >&2
    exit 1
fi

# Create new session
NOW=$(date +%s)
SESSION_ID=$(sqlite3 "$DB" "INSERT INTO sessions (client, start_time) VALUES ('${ESCAPED_CLIENT}', ${NOW}); SELECT last_insert_rowid();") || {
    echo "⚠️  Failed to create session in database" >&2
    exit 1
}

# Validate session ID
if [[ -z "$SESSION_ID" ]] || [[ "$SESSION_ID" -eq 0 ]]; then
    echo "⚠️  Invalid session ID returned from database" >&2
    exit 1
fi

# Start background tracker
# Make sure the daemon is executable
DAEMON_SCRIPT="${HOME}/.local/bin/sakurajima-time-tracker-daemon"
if [[ ! -x "$DAEMON_SCRIPT" ]]; then
    DAEMON_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sakurajima-time-tracker-daemon.sh"
fi

# Verify daemon script exists
if [[ ! -x "$DAEMON_SCRIPT" ]]; then
    echo "⚠️  Tracker daemon not found or not executable: $DAEMON_SCRIPT" >&2
    exit 1
fi

nohup "$DAEMON_SCRIPT" "$SESSION_ID" > /dev/null 2>&1 &
TRACKER_PID=$!

# Verify tracker started
sleep 0.2
if ! kill -0 "$TRACKER_PID" 2>/dev/null; then
    echo "⚠️  Failed to start tracker daemon" >&2
    # Clean up the session we just created
    sqlite3 "$DB" "DELETE FROM sessions WHERE id = ${SESSION_ID};" 2>/dev/null || true
    exit 1
fi

# Write state file with proper shell quoting
cat > "$STATE_FILE" <<STATE
CLIENT='${CLIENT//\'/\'\\\'\'}'
SESSION_ID=${SESSION_ID}
PID=$$
TRACKER_PID=${TRACKER_PID}
STATE

echo "✅ Started tracking: $CLIENT (session ${SESSION_ID})"

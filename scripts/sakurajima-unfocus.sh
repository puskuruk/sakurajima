#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Stop the current time tracking session

# Source common library for validation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    validate_numeric() { [[ "$1" =~ ^[0-9]+$ ]]; }
fi

CONFIG_DIR="${HOME}/.config/sakurajima"
DB="${CONFIG_DIR}/time-tracking.db"
STATE_FILE="${CONFIG_DIR}/active-session.state"

# Check if there's an active session
if [[ ! -f "$STATE_FILE" ]]; then
    echo "ℹ️  No active session"
    exit 0
fi

# Verify database exists
if [[ ! -f "$DB" ]]; then
    echo "⚠️  Database not found, removing state file" >&2
    rm -f "$STATE_FILE"
    exit 1
fi

# Read state file
source "$STATE_FILE"
SESSION_CLIENT="${CLIENT:-unknown}"
SESSION_ID="${SESSION_ID:-0}"

# Validate session_id is numeric and non-zero
if ! validate_numeric "$SESSION_ID" || [[ "$SESSION_ID" -eq 0 ]]; then
    echo "⚠️  Invalid session ID in state file" >&2
    rm -f "$STATE_FILE"
    exit 1
fi

# Stop tracker process
if [[ -n "${TRACKER_PID:-}" ]] && kill -0 "$TRACKER_PID" 2>/dev/null; then
    kill "$TRACKER_PID" 2>/dev/null || true
    # Give it a moment to die gracefully
    sleep 0.5
    # Force kill if still alive
    if kill -0 "$TRACKER_PID" 2>/dev/null; then
        kill -9 "$TRACKER_PID" 2>/dev/null || true
    fi
fi

# Update session end time and duration (SESSION_ID validated as numeric above)
NOW=$(date +%s)
if sqlite3 "$DB" "UPDATE sessions SET end_time = ${NOW}, duration = ${NOW} - start_time WHERE id = ${SESSION_ID};"; then
    # Get session info for display
    DURATION=$(sqlite3 "$DB" "SELECT COALESCE(duration, 0) FROM sessions WHERE id = ${SESSION_ID};" 2>/dev/null) || DURATION=0
    HOURS=$((DURATION / 3600))
    MINS=$(( (DURATION % 3600) / 60))

    # Remove state file
    rm -f "$STATE_FILE"

    echo "✅ Stopped tracking: ${SESSION_CLIENT} (${HOURS}h ${MINS}m)"
else
    echo "⚠️  Failed to update session in database" >&2
    rm -f "$STATE_FILE"
    exit 1
fi

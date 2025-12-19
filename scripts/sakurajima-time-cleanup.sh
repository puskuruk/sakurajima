#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Clean up stale time tracking sessions
# - Detects state file with dead tracker process
# - Closes old sessions with NULL end_time

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

# Check if database exists
if [[ ! -f "$DB" ]]; then
    # If state file exists but no database, just remove the state file
    if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE"
        echo "✅ Removed orphaned state file"
    else
        echo "ℹ️  No database to clean"
    fi
    exit 0
fi

CLEANED=0

# Clean up state file if tracker is dead
if [[ -f "$STATE_FILE" ]]; then
    source "$STATE_FILE"
    OLD_CLIENT="${CLIENT:-unknown}"
    OLD_SESSION_ID="${SESSION_ID:-0}"

    # Validate session ID is numeric before using in SQL
    if ! validate_numeric "$OLD_SESSION_ID"; then
        echo "⚠️  Invalid session ID in state file, removing" >&2
        rm -f "$STATE_FILE"
        OLD_SESSION_ID=0
    fi

    if [[ "$OLD_SESSION_ID" -gt 0 ]] && [[ -n "${TRACKER_PID:-}" ]] && ! kill -0 "$TRACKER_PID" 2>/dev/null; then
        echo "🧹 Found stale session: $OLD_CLIENT"

        # Estimate end time from last app usage activity
        END_TIME=$(sqlite3 "$DB" <<SQL
SELECT COALESCE(MAX(last_seen), start_time + 3600)
FROM app_usage
WHERE session_id = ${OLD_SESSION_ID};
SQL
        ) || END_TIME=$(($(date +%s)))

        # Update session with error handling
        if sqlite3 "$DB" <<SQL
UPDATE sessions
SET end_time = ${END_TIME},
    duration = ${END_TIME} - start_time
WHERE id = ${OLD_SESSION_ID};
SQL
        then
            # Remove state file only if database update succeeded
            rm -f "$STATE_FILE"
            echo "✅ Cleaned up session ${OLD_SESSION_ID}"
            CLEANED=$((CLEANED + 1))
        else
            echo "⚠️  Failed to update session in database" >&2
        fi
    fi
fi

# Find and clean sessions with NULL end_time older than 24 hours
OLD_THRESHOLD=$(($(date +%s) - 86400))

OLD_SESSIONS=$(sqlite3 "$DB" <<SQL
SELECT COUNT(*)
FROM sessions
WHERE end_time IS NULL
  AND start_time < ${OLD_THRESHOLD};
SQL
)

if [[ "$OLD_SESSIONS" -gt 0 ]]; then
    echo "🧹 Found ${OLD_SESSIONS} old unclosed session(s)"

    # Close them with default 8 hour duration
    sqlite3 "$DB" <<SQL
UPDATE sessions
SET end_time = start_time + 28800,
    duration = 28800
WHERE end_time IS NULL
  AND start_time < ${OLD_THRESHOLD};
SQL

    echo "✅ Closed ${OLD_SESSIONS} old session(s) (estimated 8h duration)"
    CLEANED=$((CLEANED + OLD_SESSIONS))
fi

if [[ "$CLEANED" -eq 0 ]]; then
    echo "✅ No cleanup needed"
fi

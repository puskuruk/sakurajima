#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Background daemon for tracking active application usage during a focus session
# Arguments: SESSION_ID [POLL_INTERVAL]

# Source common library for validation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    validate_numeric() { [[ "$1" =~ ^[0-9]+$ ]]; }
fi

SESSION_ID="${1:?Session ID required}"
POLL_INTERVAL="${2:-5}"  # Default 5 seconds

# Validate session ID is numeric to prevent SQL injection
if ! validate_numeric "$SESSION_ID"; then
    echo "❌ Invalid session ID: $SESSION_ID (must be numeric)" >&2
    exit 1
fi

# Validate poll interval is numeric
if ! validate_numeric "$POLL_INTERVAL"; then
    echo "❌ Invalid poll interval: $POLL_INTERVAL (must be numeric)" >&2
    exit 1
fi

CONFIG_DIR="${HOME}/.config/sakurajima"
DB="${CONFIG_DIR}/time-tracking.db"

# Verify database exists
[[ -f "$DB" ]] || { echo "❌ Database not found: $DB" >&2; exit 1; }

# Function to get active application name and bundle ID
get_active_app() {
    osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "Unknown"
}

get_active_app_bundle() {
    osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null || echo ""
}

# Function to update app usage in database
update_app_usage() {
    local app_name="$1"
    local bundle_id="$2"
    local now
    now=$(date +%s)

    # Escape single quotes in app name and bundle_id for SQL
    local escaped_app="${app_name//\'/\'\'}"
    local escaped_bundle="${bundle_id//\'/\'\'}"

    # Use database transaction for atomicity
    sqlite3 "$DB" <<SQL 2>/dev/null || return 1
BEGIN TRANSACTION;

-- Insert or update application with bundle_id
INSERT INTO applications (name, bundle_id) VALUES ('${escaped_app}', '${escaped_bundle}')
ON CONFLICT(name) DO UPDATE SET bundle_id = COALESCE(bundle_id, '${escaped_bundle}');

-- Update app_usage
INSERT INTO app_usage (session_id, application_id, total_seconds, last_seen)
SELECT ${SESSION_ID}, id, ${POLL_INTERVAL}, ${now}
FROM applications WHERE name = '${escaped_app}'
ON CONFLICT(session_id, application_id) DO UPDATE SET
    total_seconds = total_seconds + ${POLL_INTERVAL},
    last_seen = ${now};

COMMIT;
SQL
}

# Main tracking loop
while true; do
    APP=$(get_active_app)
    BUNDLE=$(get_active_app_bundle)

    # Try to update, but don't crash if it fails
    if ! update_app_usage "$APP" "$BUNDLE"; then
        # Database might be locked or other transient error
        # Continue tracking instead of dying
        :
    fi

    sleep "$POLL_INTERVAL"
done

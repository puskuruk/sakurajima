#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Display time tracking statistics
# Optional argument: CLIENT_NAME (filter by specific client)

# Source common library for sql_escape and validation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    sql_escape() { printf '%s' "${1//\'/\'\'}"; }
    validate_client_name() { [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; }
fi

CLIENT="${1:-}"
CONFIG_DIR="${HOME}/.config/sakurajima"
DB="${CONFIG_DIR}/time-tracking.db"

# Check if database exists
[[ -f "$DB" ]] || { echo "ℹ️  No time tracking data"; exit 0; }

# Validate client name if provided
if [[ -n "$CLIENT" ]] && ! validate_client_name "$CLIENT"; then
    echo "⚠️  Invalid client name: $CLIENT" >&2
    exit 1
fi

# Format duration in seconds to "Xh Ym" format
format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local mins=$(( (seconds % 3600) / 60 ))
    printf "%dh %dm" "$hours" "$mins"
}

echo "📊 SAKURAJIMA TIME TRACKING STATISTICS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Per-client summary (client name validated above if provided)
if [[ -n "$CLIENT" ]]; then
    ESCAPED_CLIENT="$(sql_escape "$CLIENT")"
    SUMMARY=$(sqlite3 -separator '|' "$DB" "SELECT client, COUNT(*) as sessions, COALESCE(SUM(duration), 0) as total_seconds, CAST(COALESCE(AVG(duration), 0) AS INTEGER) as avg_seconds, MAX(start_time) as last_focused FROM sessions WHERE client = '${ESCAPED_CLIENT}' GROUP BY client ORDER BY total_seconds DESC;")
else
    SUMMARY=$(sqlite3 -separator '|' "$DB" "SELECT client, COUNT(*) as sessions, COALESCE(SUM(duration), 0) as total_seconds, CAST(COALESCE(AVG(duration), 0) AS INTEGER) as avg_seconds, MAX(start_time) as last_focused FROM sessions GROUP BY client ORDER BY total_seconds DESC;")
fi

if [[ -z "$SUMMARY" ]]; then
    echo "ℹ️  No sessions recorded yet"
    exit 0
fi

printf "%-15s %10s %15s %15s %20s\n" "CLIENT" "SESSIONS" "TOTAL TIME" "AVG SESSION" "LAST FOCUSED"
echo "────────────────────────────────────────────────────────────────────────────"

while IFS='|' read -r client sessions total avg last; do
    total_fmt=$(format_duration "$total")
    avg_fmt=$(format_duration "$avg")
    last_fmt=$(date -r "$last" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
    printf "%-15s %10s %15s %15s %20s\n" "$client" "$sessions" "$total_fmt" "$avg_fmt" "$last_fmt"
done <<< "$SUMMARY"

# Application usage breakdown (only if specific client requested)
if [[ -n "$CLIENT" ]]; then
    echo
    echo "📱 APPLICATION USAGE: $CLIENT"
    echo "────────────────────────────────────────────────────────────────────────────"

    APP_USAGE=$(sqlite3 -separator '|' "$DB" "SELECT a.name, SUM(au.total_seconds) as total_seconds FROM app_usage au JOIN applications a ON au.application_id = a.id JOIN sessions s ON au.session_id = s.id WHERE s.client = '${ESCAPED_CLIENT}' GROUP BY a.name ORDER BY total_seconds DESC LIMIT 10;")

    if [[ -n "$APP_USAGE" ]]; then
        printf "%-50s %15s\n" "APPLICATION" "TIME"
        echo "────────────────────────────────────────────────────────────────────────────"

        while IFS='|' read -r app_name seconds; do
            time_fmt=$(format_duration "$seconds")
            printf "%-50s %15s\n" "$app_name" "$time_fmt"
        done <<< "$APP_USAGE"
    else
        echo "ℹ️  No application usage data for $CLIENT"
    fi
fi

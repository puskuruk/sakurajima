#!/usr/bin/env bash
# Sakurajima Common Library
# Source this file in all scripts to DRY up helper functions
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
#   or from scripts/lib/ directory:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ANSI color codes
BOLD=$'\033[1m'
RESET=$'\033[0m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'

# Output helpers
bold() {
    echo "${BOLD}${1}${RESET}"
}

ok() {
    echo "${GREEN}✓${RESET} $*"
}

info() {
    echo "${BOLD}→${RESET} $*"
}

warn() {
    echo "${YELLOW}⚠${RESET} $*" >&2
}

die() {
    echo "${RED}✗${RESET} $*" >&2
    exit 1
}

error() {
    echo "${RED}ERROR:${RESET} $*" >&2
}

success() {
    echo "${GREEN}SUCCESS:${RESET} $*"
}

# Command existence checker
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Required command not found: $cmd"
    fi
}

# File existence checker
require_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        die "Required file not found: $file"
    fi
}

# Directory existence checker
require_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        die "Required directory not found: $dir"
    fi
}

# Ensure directory exists
ensure_dir() {
    local dir
    for dir in "$@"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || die "Failed to create directory: $dir"
        fi
    done
}

# Safe symlink creation (won't overwrite existing files)
ensure_symlink() {
    local target="$1"
    local link="$2"

    if [[ -L "$link" ]]; then
        # Already a symlink - check if it points to the right place
        local current_target
        current_target=$(readlink "$link")
        if [[ "$current_target" == "$target" ]]; then
            return 0  # Already correct
        else
            warn "Symlink exists but points to wrong target: $link -> $current_target (expected: $target)"
            return 1
        fi
    elif [[ -e "$link" ]]; then
        warn "File exists and is not a symlink: $link"
        return 1
    else
        ln -s "$target" "$link" || die "Failed to create symlink: $link -> $target"
        ok "Created symlink: $link -> $target"
    fi
}

# Strict symlink creation (dies if target exists and is not the correct symlink)
ensure_symlink_strict() {
    local target="$1"
    local link="$2"

    if [[ -L "$link" ]]; then
        local current_target
        current_target=$(readlink "$link")
        if [[ "$current_target" == "$target" ]]; then
            return 0
        else
            die "Symlink exists but points to wrong target: $link -> $current_target (expected: $target)"
        fi
    elif [[ -e "$link" ]]; then
        die "File exists and is not a symlink: $link"
    else
        ln -s "$target" "$link" || die "Failed to create symlink: $link -> $target"
    fi
}

# Cleanup handler for temporary files
# Usage: register_cleanup "file1" "file2" ...
CLEANUP_FILES=()
register_cleanup() {
    CLEANUP_FILES+=("$@")
}

cleanup() {
    local file
    for file in "${CLEANUP_FILES[@]}"; do
        if [[ -f "$file" ]] || [[ -d "$file" ]]; then
            rm -rf "$file" 2>/dev/null || true
        fi
    done
}

# Set up cleanup trap
trap cleanup EXIT ERR INT TERM

# Confirm prompt
confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        read -p "$prompt (Y/n) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]?$ ]]
    else
        read -p "$prompt (y/N) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Version comparison (returns 0 if version1 >= version2)
version_gte() {
    local version1="$1"
    local version2="$2"

    # Use sort -V (version sort) to compare
    printf '%s\n%s\n' "$version1" "$version2" | sort -V -C
}

# Check if running on macOS
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Check if running with sudo/root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Get macOS version (e.g., "14.2" for Sonoma 14.2)
macos_version() {
    sw_vers -productVersion 2>/dev/null || echo "unknown"
}

# SQL escape for sqlite3 CLI (escapes single quotes by doubling them)
# Usage: sqlite3 "$DB" "INSERT INTO t (col) VALUES ('$(sql_escape "$value")');"
sql_escape() {
    local value="$1"
    # Escape single quotes by doubling them (SQL standard)
    printf '%s' "${value//\'/\'\'}"
}

# Validate client name (kebab-case only: lowercase, numbers, hyphens)
# Prevents path traversal and SQL injection through strict validation
validate_client_name() {
    local name="$1"
    [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

# Validate numeric value (for session IDs, timestamps, etc.)
validate_numeric() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]]
}

# Export all functions and variables
export BOLD RESET RED GREEN YELLOW BLUE MAGENTA CYAN
export -f bold ok info warn die error success
export -f require_cmd require_file require_dir ensure_dir
export -f ensure_symlink ensure_symlink_strict
export -f cleanup register_cleanup confirm
export -f version_gte is_macos is_root macos_version
export -f sql_escape validate_client_name validate_numeric

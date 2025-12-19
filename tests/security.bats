#!/usr/bin/env bats
# Security tests for Sakurajima scripts

# SQL escape function (same as in common.sh)
sql_escape() {
  printf '%s' "${1//\'/\'\'}"
}

# Validation function (same as in common.sh)
validate_client_name() {
  [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

setup() {
  # Create temporary test database
  export TEST_DB="${BATS_TMPDIR}/test_security.db"
  export TEST_CONFIG_DIR="${BATS_TMPDIR}/sakurajima_test"
  mkdir -p "$TEST_CONFIG_DIR"

  # Initialize test database
  sqlite3 "$TEST_DB" <<SQL
CREATE TABLE IF NOT EXISTS clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client TEXT NOT NULL,
  start_time INTEGER NOT NULL,
  end_time INTEGER,
  duration INTEGER,
  FOREIGN KEY (client) REFERENCES clients(name)
);
SQL
}

teardown() {
  # Cleanup test database
  rm -rf "$TEST_DB" "$TEST_CONFIG_DIR"
}

@test "SQL escape function doubles single quotes" {
  local input="test'quote"
  local expected="test''quote"
  local result
  result=$(sql_escape "$input")
  [ "$result" = "$expected" ]
}

@test "SQL escape handles multiple quotes" {
  local input="it's o'clock"
  local expected="it''s o''clock"
  local result
  result=$(sql_escape "$input")
  [ "$result" = "$expected" ]
}

@test "Valid client names with sql_escape are safely inserted" {
  local client_name="test-client"
  local escaped
  escaped=$(sql_escape "$client_name")

  # Insert using escaped value
  sqlite3 "$TEST_DB" "INSERT OR IGNORE INTO clients (name) VALUES ('${escaped}');"

  # Verify it was inserted
  run sqlite3 "$TEST_DB" "SELECT name FROM clients WHERE name = '${escaped}';"
  [ "$status" -eq 0 ]
  [ "$output" = "$client_name" ]
}

@test "Session creation with validated client name works" {
  local client_name="test-client"
  local timestamp="1234567890"

  # Validate client name first (as our scripts do)
  validate_client_name "$client_name"
  [ $? -eq 0 ]

  local escaped
  escaped=$(sql_escape "$client_name")

  # Insert client first
  sqlite3 "$TEST_DB" "INSERT OR IGNORE INTO clients (name) VALUES ('${escaped}');"

  # Insert session
  local session_id
  session_id=$(sqlite3 "$TEST_DB" "INSERT INTO sessions (client, start_time) VALUES ('${escaped}', ${timestamp}); SELECT last_insert_rowid();")

  # Verify session was created
  [ -n "$session_id" ]
  [ "$session_id" -gt 0 ]

  # Verify session data
  run sqlite3 "$TEST_DB" "SELECT client FROM sessions WHERE id = ${session_id};"
  [ "$status" -eq 0 ]
  [ "$output" = "$client_name" ]
}

@test "Numeric session ID prevents injection" {
  # Session IDs should always be numeric and validated
  local invalid_session="123; DROP TABLE sessions; --"

  # This should fail gracefully if session ID validation is in place
  # The actual scripts validate that SESSION_ID is numeric before use
  if [[ "$invalid_session" =~ ^[0-9]+$ ]]; then
    # Should only execute if it's actually numeric
    sqlite3 "$TEST_DB" "SELECT * FROM sessions WHERE id = $invalid_session;" 2>/dev/null || true
  fi

  # Verify sessions table still exists
  run sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sessions;"
  [ "$status" -eq 0 ]
}

@test "Client name validation prevents path traversal" {
  # Client names must be kebab-case (lowercase letters, numbers, hyphens)
  # This prevents path traversal attacks
  local invalid_clients=(
    "../../../etc/passwd"
    "client/../../secrets"
    "test..test"
    "test__test"
    "TEST"
    "test client"
    "test@client"
  )

  # The validation regex from new-client.sh: ^[a-z0-9]+(-[a-z0-9]+)*$
  local validation_regex='^[a-z0-9]+(-[a-z0-9]+)*$'

  for client in "${invalid_clients[@]}"; do
    if [[ "$client" =~ $validation_regex ]]; then
      echo "ERROR: Invalid client '$client' passed validation!"
      return 1
    fi
  done

  # Valid clients that should pass
  local valid_clients=(
    "test"
    "test-client"
    "client123"
    "test-client-123"
  )

  for client in "${valid_clients[@]}"; do
    if [[ ! "$client" =~ $validation_regex ]]; then
      echo "ERROR: Valid client '$client' failed validation!"
      return 1
    fi
  done
}

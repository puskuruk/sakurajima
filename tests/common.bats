#!/usr/bin/env bats
# Tests for scripts/lib/common.sh

setup() {
  # Load the common library
  source "${BATS_TEST_DIRNAME}/../scripts/lib/common.sh"
}

@test "bold() outputs text with bold formatting" {
  run bold "test message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test message" ]]
}

@test "ok() outputs success message with checkmark" {
  run ok "success message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
  [[ "$output" =~ "success message" ]]
}

@test "info() outputs info message" {
  run info "info message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "→" ]]
  [[ "$output" =~ "info message" ]]
}

@test "warn() outputs warning to stderr" {
  run warn "warning message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "⚠" ]]
  [[ "$output" =~ "warning message" ]]
}

@test "die() exits with status 1" {
  run die "error message"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "✗" ]]
  [[ "$output" =~ "error message" ]]
}

@test "is_macos() returns true on macOS" {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    run is_macos
    [ "$status" -eq 0 ]
  else
    skip "Not running on macOS"
  fi
}

@test "ensure_dir() creates directory if missing" {
  local test_dir="${BATS_TMPDIR}/test_ensure_dir"
  rm -rf "$test_dir"

  run ensure_dir "$test_dir"
  [ "$status" -eq 0 ]
  [ -d "$test_dir" ]

  # Cleanup
  rm -rf "$test_dir"
}

@test "ensure_dir() succeeds if directory already exists" {
  local test_dir="${BATS_TMPDIR}/test_ensure_dir_exists"
  mkdir -p "$test_dir"

  run ensure_dir "$test_dir"
  [ "$status" -eq 0 ]
  [ -d "$test_dir" ]

  # Cleanup
  rm -rf "$test_dir"
}

@test "require_cmd() succeeds for existing command" {
  run require_cmd "bash"
  [ "$status" -eq 0 ]
}

@test "require_cmd() fails for non-existent command" {
  run require_cmd "this_command_does_not_exist_xyz123"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Required command not found" ]]
}

@test "require_file() succeeds for existing file" {
  local test_file="${BATS_TMPDIR}/test_require_file"
  touch "$test_file"

  run require_file "$test_file"
  [ "$status" -eq 0 ]

  # Cleanup
  rm -f "$test_file"
}

@test "require_file() fails for non-existent file" {
  run require_file "/this/file/does/not/exist/xyz123"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Required file not found" ]]
}

@test "ensure_symlink() creates symlink correctly" {
  local test_target="${BATS_TMPDIR}/symlink_target"
  local test_link="${BATS_TMPDIR}/symlink_link"

  echo "test content" > "$test_target"
  rm -f "$test_link"

  run ensure_symlink "$test_target" "$test_link"
  [ "$status" -eq 0 ]
  [ -L "$test_link" ]

  # Verify symlink points to correct target
  local link_target
  link_target=$(readlink "$test_link")
  [ "$link_target" = "$test_target" ]

  # Cleanup
  rm -f "$test_target" "$test_link"
}

@test "version_gte() compares versions correctly" {
  run version_gte "2.0" "1.0"
  [ "$status" -eq 0 ]

  run version_gte "1.0" "2.0"
  [ "$status" -eq 1 ]

  run version_gte "1.0" "1.0"
  [ "$status" -eq 0 ]
}

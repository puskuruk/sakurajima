#!/usr/bin/env bats
# Integration tests for Sakurajima scripts

@test "All shell scripts have correct shebang" {
  local failed=0
  while IFS= read -r -d '' script; do
    # Check first line is a valid shebang
    local first_line
    first_line=$(head -n 1 "$script")

    if [[ ! "$first_line" =~ ^#!/(usr/bin/env\ bash|bin/bash) ]]; then
      echo "Invalid shebang in $script: $first_line" >&2
      failed=$((failed + 1))
    fi
  done < <(find "${BATS_TEST_DIRNAME}/../scripts" -type f -name "*.sh" -print0)

  [ "$failed" -eq 0 ]
}

@test "All shell scripts use strict mode" {
  local failed=0
  while IFS= read -r -d '' script; do
    # Skip library files (they're sourced by scripts that have strict mode)
    [[ "$script" == *"/lib/"* ]] && continue

    # Check for set -Eeuo pipefail
    if ! grep -q "set -Eeuo pipefail" "$script"; then
      echo "Missing strict mode in $script" >&2
      failed=$((failed + 1))
    fi
  done < <(find "${BATS_TEST_DIRNAME}/../scripts" -type f -name "*.sh" -print0)

  [ "$failed" -eq 0 ]
}

@test "All shell scripts set IFS correctly" {
  local failed=0
  while IFS= read -r -d '' script; do
    # Skip library files (they're sourced by scripts that have IFS set)
    [[ "$script" == *"/lib/"* ]] && continue

    # Check for IFS=$'\n\t'
    if ! grep -q "IFS=" "$script"; then
      echo "Missing IFS setting in $script" >&2
      failed=$((failed + 1))
    fi
  done < <(find "${BATS_TEST_DIRNAME}/../scripts" -type f -name "*.sh" -print0)

  [ "$failed" -eq 0 ]
}

@test "No scripts use dangerous eval without trusted source" {
  # eval is dangerous but acceptable for trusted sources like brew, direnv
  local suspicious_evals=()

  while IFS= read -r -d '' script; do
    # Look for eval that's not from known trusted sources
    if grep -E 'eval.*\$' "$script" | grep -qv -E '(brew shellenv|direnv hook|starship init|mise activate)'; then
      suspicious_evals+=("$script")
    fi
  done < <(find "${BATS_TEST_DIRNAME}/../scripts" -type f -name "*.sh" -print0)

  if [ ${#suspicious_evals[@]} -gt 0 ]; then
    echo "Suspicious eval usage found in: ${suspicious_evals[*]}" >&2
    return 1
  fi
}

@test "No hardcoded credentials in scripts" {
  local found_creds=0

  while IFS= read -r -d '' script; do
    # Look for common credential patterns (case insensitive)
    if grep -iE '(password|secret|api[_-]?key|token).*=.*["\047]' "$script" | grep -qv -E '(password_required|passphrase)'; then
      echo "Potential hardcoded credentials in $script" >&2
      found_creds=$((found_creds + 1))
    fi
  done < <(find "${BATS_TEST_DIRNAME}/../scripts" -type f -name "*.sh" -print0)

  [ "$found_creds" -eq 0 ]
}

@test "Time tracking scripts validate input before SQL" {
  # Check that scripts using sqlite3 with variables also have validation
  local missing_validation=0

  while IFS= read -r -d '' script; do
    # Skip init script (uses only static SQL with quoted heredoc)
    [[ "$script" == *"time-init"* ]] && continue

    # Scripts with sqlite3 + variable usage should have validation
    if grep -q 'sqlite3.*\$' "$script" || grep -q 'sqlite3.*\${' "$script"; then
      if ! grep -qE '(source.*common\.sh|validate_client_name|validate_numeric)' "$script"; then
        echo "Missing validation in $script (has sqlite3 with variables but no validation)" >&2
        missing_validation=$((missing_validation + 1))
      fi
    fi
  done < <(find "${BATS_TEST_DIRNAME}/../scripts" -type f -name "sakurajima-*.sh" -print0)

  [ "$missing_validation" -eq 0 ]
}

@test "verify-system script exists and is executable" {
  [ -f "${BATS_TEST_DIRNAME}/../scripts/verify-system.sh" ]
  [ -x "${BATS_TEST_DIRNAME}/../scripts/verify-system.sh" ]
}

@test "install.sh exists and has proper structure" {
  local install_script="${BATS_TEST_DIRNAME}/../install.sh"

  [ -f "$install_script" ]
  [ -x "$install_script" ]

  # Should have require_file checks
  grep -q "require_file" "$install_script"

  # Should have ensure_symlink functions
  grep -q "ensure_symlink" "$install_script"
}

@test "skr CLI script exists and is properly structured" {
  local skr_script="${BATS_TEST_DIRNAME}/../scripts/skr"

  [ -f "$skr_script" ]
  [ -x "$skr_script" ]

  # Should have help command
  grep -q "help" "$skr_script"

  # Should have version
  grep -q "VERSION" "$skr_script"
}

@test "All required documentation files exist" {
  local docs_dir="${BATS_TEST_DIRNAME}/../docs"

  # Core docs in docs/ directory
  [ -f "${docs_dir}/how-to-use.md" ]
  [ -f "${docs_dir}/onboarding-playbook.md" ]
  [ -f "${docs_dir}/new-hire-checklist.md" ]

  # Root level install/format docs
  [ -f "${BATS_TEST_DIRNAME}/../INSTALL.md" ] || [ -f "${docs_dir}/INSTALL.md" ]
}

@test "Brewfile exists and contains essential packages" {
  local brewfile="${BATS_TEST_DIRNAME}/../Brewfile"

  [ -f "$brewfile" ]

  # Essential packages
  grep -q 'brew "git"' "$brewfile"
  grep -q 'brew "shellcheck"' "$brewfile"
  grep -q 'brew "bats-core"' "$brewfile"
}

@test "No temp files left behind in scripts directory" {
  local temp_files=()
  temp_files=($(find "${BATS_TEST_DIRNAME}/../scripts" -type f -name "*.tmp" -o -name "tmp.*"))

  [ ${#temp_files[@]} -eq 0 ]
}

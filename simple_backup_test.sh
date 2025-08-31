#!/bin/bash

# Simple test runner for backup system (no bats required)

source src/backup_system.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory setup
TEST_DIR=$(mktemp -d)
TEST_PAM_DIR="$TEST_DIR/pam.d"
TEST_BACKUP_BASE="$TEST_DIR/backups"
TEST_LOG_FILE="$TEST_DIR/test.log"

# Cleanup function
cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test helper function
run_test() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  ((TESTS_RUN++))

  if [[ "$actual" == *"$expected"* ]]; then
    echo -e "${GREEN}✓${NC} $test_name"
    ((TESTS_PASSED++))
  else
    echo -e "${RED}✗${NC} $test_name"
    echo "  Expected: $expected"
    echo "  Got: $actual"
    ((TESTS_FAILED++))
  fi
}

# Setup test environment
setup_test_env() {
  mkdir -p "$TEST_PAM_DIR"
  mkdir -p "$TEST_BACKUP_BASE"

  # Create mock PAM files
  echo "auth required pam_unix.so" >"$TEST_PAM_DIR/sudo"
  echo "auth required pam_unix.so" >"$TEST_PAM_DIR/su"
  echo "@include common-auth" >"$TEST_PAM_DIR/login"
  echo "account required pam_unix.so" >"$TEST_PAM_DIR/common-account"

  # Set permissions
  chmod 644 "$TEST_PAM_DIR"/*
}

echo "==================================="
echo "Running Backup System Tests"
echo "==================================="
echo ""

# Setup
setup_test_env

# Test 1: Create timestamped backup directory
echo "Testing backup directory creation..."
backup_dir=$(create_backup_directory "$TEST_BACKUP_BASE")
run_test "Create timestamped directory" "pam.d.backup-" "$backup_dir"

# Check timestamp format
if [[ "$backup_dir" =~ [0-9]{8}-[0-9]{6}$ ]]; then
  result="valid_timestamp"
else
  result="invalid_timestamp"
fi
run_test "Timestamp format (YYYYMMDD-HHMMSS)" "valid_timestamp" "$result"

# Test 2: Backup PAM configuration
echo ""
echo "Testing PAM backup..."
backup_dir=$(create_backup_directory "$TEST_BACKUP_BASE")
backup_pam_config "$TEST_PAM_DIR" "$backup_dir" >/dev/null 2>&1
if [[ -f "$backup_dir/sudo" ]] && [[ -f "$backup_dir/su" ]]; then
  backup_result="files_copied"
else
  backup_result="backup_failed"
fi
run_test "Backup copies all files" "files_copied" "$backup_result"

# Test 3: Permission preservation
echo ""
echo "Testing permission preservation..."
chmod 600 "$TEST_PAM_DIR/sudo"
backup_dir=$(create_backup_directory "$TEST_BACKUP_BASE")
backup_pam_config "$TEST_PAM_DIR" "$backup_dir" >/dev/null 2>&1
backup_perms=$(stat -c %a "$backup_dir/sudo" 2>/dev/null)
run_test "Preserves file permissions" "600" "$backup_perms"

# Test 4: Backup verification
echo ""
echo "Testing backup verification..."
chmod 644 "$TEST_PAM_DIR/sudo" # Reset permissions
backup_dir=$(create_backup_directory "$TEST_BACKUP_BASE")
backup_pam_config "$TEST_PAM_DIR" "$backup_dir" >/dev/null 2>&1
verify_result=$(verify_backup "$TEST_PAM_DIR" "$backup_dir" 2>&1)
run_test "Verify identical backup" "verified successfully" "$verify_result"

# Modify and test difference detection
echo "modified" >>"$TEST_PAM_DIR/sudo"
verify_backup "$TEST_PAM_DIR" "$backup_dir" >/dev/null 2>&1 && diff_result="no_diff" || diff_result="diff_found"
run_test "Detect backup differences" "diff_found" "$diff_result"

# Test 5: Logging
echo ""
echo "Testing logging functionality..."
log_action "TEST" "Test message" "$TEST_LOG_FILE"
if [[ -f "$TEST_LOG_FILE" ]] && grep -q "TEST" "$TEST_LOG_FILE"; then
  log_result="logged"
else
  log_result="not_logged"
fi
run_test "Log action to file" "logged" "$log_result"

# Check timestamp in log
if grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" "$TEST_LOG_FILE" >/dev/null; then
  timestamp_result="has_timestamp"
else
  timestamp_result="no_timestamp"
fi
run_test "Log includes timestamp" "has_timestamp" "$timestamp_result"

# Test 6: Restore functionality
echo ""
echo "Testing restore functionality..."
setup_test_env # Reset environment
backup_dir=$(create_backup_directory "$TEST_BACKUP_BASE")
backup_pam_config "$TEST_PAM_DIR" "$backup_dir" >/dev/null 2>&1

# Modify original files
echo "modified content" >"$TEST_PAM_DIR/sudo"

# Restore from backup
restore_from_backup "$backup_dir" "$TEST_PAM_DIR" >/dev/null 2>&1
restored_content=$(cat "$TEST_PAM_DIR/sudo")
run_test "Restore original content" "auth required pam_unix.so" "$restored_content"

# Test 7: List backups
echo ""
echo "Testing backup listing..."
backup1=$(create_backup_directory "$TEST_BACKUP_BASE")
sleep 1
backup2=$(create_backup_directory "$TEST_BACKUP_BASE")
list_output=$(list_backups "$TEST_BACKUP_BASE" 2>/dev/null)
if [[ "$list_output" =~ $(basename "$backup1") ]] && [[ "$list_output" =~ $(basename "$backup2") ]]; then
  list_result="both_listed"
else
  list_result="missing_backups"
fi
run_test "List all backups" "both_listed" "$list_result"

# Test 8: Get latest backup
echo ""
echo "Testing latest backup retrieval..."
latest=$(get_latest_backup "$TEST_BACKUP_BASE")
run_test "Get latest backup" "$(basename "$backup2")" "$(basename "$latest")"

# Test 9: Disk space check
echo ""
echo "Testing disk space checks..."
check_disk_space "$TEST_BACKUP_BASE" 1 >/dev/null 2>&1 && space_result="sufficient" || space_result="insufficient"
run_test "Check sufficient disk space" "sufficient" "$space_result"

# Request impossible amount
check_disk_space "$TEST_BACKUP_BASE" 999999999 >/dev/null 2>&1 && huge_space="sufficient" || huge_space="insufficient"
run_test "Detect insufficient space" "insufficient" "$huge_space"

# Test 10: Backup metadata
echo ""
echo "Testing backup metadata..."
backup_dir=$(create_backup_directory "$TEST_BACKUP_BASE")
save_backup_metadata "$backup_dir" "Test backup description"
if [[ -f "$backup_dir/.backup_metadata" ]]; then
  metadata_result="saved"
else
  metadata_result="not_saved"
fi
run_test "Save backup metadata" "saved" "$metadata_result"

metadata_content=$(read_backup_metadata "$backup_dir" 2>/dev/null)
run_test "Read backup metadata" "Test backup description" "$metadata_content"

# Test 11: Error handling
echo ""
echo "Testing error handling..."
restore_from_backup "/nonexistent/path" "$TEST_PAM_DIR" >/dev/null 2>&1 && invalid_restore="success" || invalid_restore="failed"
run_test "Handle invalid backup path" "failed" "$invalid_restore"

backup_pam_config "/nonexistent/source" "$TEST_BACKUP_BASE/test" >/dev/null 2>&1 && invalid_source="success" || invalid_source="failed"
run_test "Handle invalid source directory" "failed" "$invalid_source"

# Print summary
echo ""
echo "==================================="
echo "Test Summary"
echo "==================================="
echo "Tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi

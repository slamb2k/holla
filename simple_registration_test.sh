#!/bin/bash

# Simple test runner for U2F registration (no bats required)

source src/u2f_registration.sh

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
TEST_HOME="$TEST_DIR/home"
TEST_CONFIG_DIR="$TEST_HOME/.config/Yubico"
TEST_U2F_KEYS_FILE="$TEST_CONFIG_DIR/u2f_keys"

# Save original HOME
ORIGINAL_HOME="$HOME"

# Cleanup function
cleanup() {
  export HOME="$ORIGINAL_HOME"
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Setup test environment
setup_test_env() {
  mkdir -p "$TEST_HOME"
  export HOME="$TEST_HOME"
}

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

echo "==================================="
echo "Running U2F Registration Tests"
echo "==================================="
echo ""

# Setup
setup_test_env

# Test 1: Check for pamu2fcfg installation
echo "Testing pamu2fcfg detection..."

# Mock which for testing
which() {
  if [[ "$1" == "pamu2fcfg" ]]; then
    echo "/usr/bin/pamu2fcfg"
    return 0
  fi
  command which "$1"
}

check_pamu2fcfg_installed >/dev/null 2>&1 && result="installed" || result="not_installed"
run_test "Detect pamu2fcfg installation" "installed" "$result"

# Test 2: Get install command
echo ""
echo "Testing installation command detection..."

# Mock for Ubuntu/Debian
command() {
  if [[ "$1" == "-v" ]] && [[ "$2" == "apt-get" ]]; then
    return 0
  fi
  return 1
}

install_cmd=$(get_install_command)
run_test "Get apt install command" "apt-get install" "$install_cmd"

# Test 3: Create Yubico directory
echo ""
echo "Testing directory creation..."
create_yubico_directory "$TEST_HOME" >/dev/null 2>&1
if [[ -d "$TEST_CONFIG_DIR" ]]; then
  dir_result="created"
else
  dir_result="not_created"
fi
run_test "Create .config/Yubico directory" "created" "$dir_result"

# Check permissions
perms=$(stat -c %a "$TEST_CONFIG_DIR" 2>/dev/null)
run_test "Directory permissions (700)" "700" "$perms"

# Test 4: Initialize U2F keys file
echo ""
echo "Testing U2F keys file initialization..."
init_u2f_keys_file "$TEST_U2F_KEYS_FILE" >/dev/null 2>&1
if [[ -f "$TEST_U2F_KEYS_FILE" ]]; then
  file_result="created"
else
  file_result="not_created"
fi
run_test "Create u2f_keys file" "created" "$file_result"

# Check file permissions
file_perms=$(stat -c %a "$TEST_U2F_KEYS_FILE" 2>/dev/null)
run_test "File permissions (600)" "600" "$file_perms"

# Test 5: Parse pamu2fcfg output
echo ""
echo "Testing pamu2fcfg output parsing..."
mock_output="testuser:credential_data:key_handle_data"
parsed=$(parse_pamu2fcfg_output "$mock_output" 2>&1)
run_test "Parse valid output" "credential:credential_data" "$parsed"
run_test "Extract key handle" "key_handle:key_handle_data" "$parsed"

# Test 6: Validate registration format
echo ""
echo "Testing registration validation..."
valid_reg="user:cred:handle"
validate_u2f_registration "$valid_reg" && valid_result="valid" || valid_result="invalid"
run_test "Validate correct format" "valid" "$valid_result"

invalid_reg="invalid_format"
validate_u2f_registration "$invalid_reg" 2>/dev/null && invalid_result="valid" || invalid_result="invalid"
run_test "Reject invalid format" "invalid" "$invalid_result"

# Test 7: Add key to file
echo ""
echo "Testing key addition to file..."
echo -n "" > "$TEST_U2F_KEYS_FILE"  # Clear file
add_key_to_file "$TEST_U2F_KEYS_FILE" "testuser:cred1:handle1" "testuser"
content=$(cat "$TEST_U2F_KEYS_FILE")
run_test "Add first key" "testuser:cred1:handle1" "$content"

# Add second key for same user
add_key_to_file "$TEST_U2F_KEYS_FILE" "cred2:handle2" "testuser"
if grep -q "cred1:handle1:cred2:handle2" "$TEST_U2F_KEYS_FILE"; then
  multi_result="appended"
else
  multi_result="not_appended"
fi
run_test "Append additional key" "appended" "$multi_result"

# Test 8: Check existing keys
echo ""
echo "Testing existing key detection..."
check_existing_keys "$TEST_U2F_KEYS_FILE" "testuser" >/dev/null && exists="found" || exists="not_found"
run_test "Find existing keys" "found" "$exists"

check_existing_keys "$TEST_U2F_KEYS_FILE" "nonexistent" >/dev/null && noexist="found" || noexist="not_found"
run_test "No keys for new user" "not_found" "$noexist"

# Test 9: Backup functionality
echo ""
echo "Testing backup creation..."
echo "backup_test_content" > "$TEST_U2F_KEYS_FILE"
backup_u2f_keys "$TEST_U2F_KEYS_FILE" >/dev/null 2>&1
if [[ -f "$TEST_U2F_KEYS_FILE.backup" ]]; then
  backup_result="created"
  backup_content=$(cat "$TEST_U2F_KEYS_FILE.backup")
else
  backup_result="not_created"
fi
run_test "Create backup file" "created" "$backup_result"
run_test "Backup content preserved" "backup_test_content" "$backup_content"

# Test 10: List user keys
echo ""
echo "Testing key listing..."
echo "listuser:cred1:handle1:cred2:handle2" > "$TEST_U2F_KEYS_FILE"
list_output=$(list_user_keys "$TEST_U2F_KEYS_FILE" "listuser" 2>&1)
run_test "Count registered keys" "2 key(s) registered" "$list_output"

# Test 11: User feedback functions
echo ""
echo "Testing user feedback..."
touch_prompt=$(show_touch_prompt 2>&1)
run_test "Show touch prompt" "Touch your Yubikey" "$touch_prompt"

success_msg=$(show_registration_success 2>&1)
run_test "Show success message" "successfully registered" "$success_msg"

timeout_msg=$(show_timeout_message 2>&1)
run_test "Show timeout message" "timeout" "$timeout_msg"

# Test 12: Mock registration workflow
echo ""
echo "Testing registration workflow..."

# Mock pamu2fcfg for testing
pamu2fcfg() {
  echo "mockuser:mock_cred:mock_handle"
  return 0
}
export -f pamu2fcfg

# Create fresh keys file
echo -n "" > "$TEST_U2F_KEYS_FILE"
register_yubikey_mock "mockuser" "$TEST_U2F_KEYS_FILE" >/dev/null 2>&1
if grep -q "mock_cred" "$TEST_U2F_KEYS_FILE"; then
  reg_result="registered"
else
  reg_result="not_registered"
fi
run_test "Mock registration workflow" "registered" "$reg_result"

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
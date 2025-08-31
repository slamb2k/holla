#!/bin/bash

# Simple test runner for PAM parser (no bats required)

source src/pam_parser.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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
echo "Running PAM Parser Tests"
echo "==================================="
echo ""

# Test 1: Parse valid PAM auth line
echo "Testing PAM line parsing..."
result=$(parse_pam_line "auth    required    pam_unix.so nullok try_first_pass")
run_test "Parse valid auth line" "module_type:auth" "$result"
run_test "Parse control flag" "control_flag:required" "$result"
run_test "Parse module path" "module_path:pam_unix.so" "$result"

# Test 2: Comment detection
echo ""
echo "Testing comment detection..."
is_comment_or_blank "# This is a comment" && comment_result="is_comment" || comment_result="not_comment"
run_test "Detect comment line" "is_comment" "$comment_result"

is_comment_or_blank "   " && blank_result="is_blank" || blank_result="not_blank"
run_test "Detect blank line" "is_blank" "$blank_result"

is_comment_or_blank "auth required pam_unix.so" && not_comment="is_comment" || not_comment="not_comment"
run_test "Reject non-comment line" "not_comment" "$not_comment"

# Test 3: U2F module detection
echo ""
echo "Testing U2F module detection..."
has_u2f_module "auth sufficient pam_u2f.so authfile=/etc/u2f_keys" && u2f_found="found" || u2f_found="not_found"
run_test "Detect pam_u2f module" "found" "$u2f_found"

has_u2f_module "auth required pam_yubico.so mode=challenge" && yubico_found="found" || yubico_found="not_found"
run_test "Detect pam_yubico module" "found" "$yubico_found"

has_u2f_module "auth required pam_unix.so" && no_u2f="found" || no_u2f="not_found"
run_test "No U2F in regular line" "not_found" "$no_u2f"

# Test 4: Include directive parsing
echo ""
echo "Testing include directives..."
result=$(parse_pam_line "@include common-auth")
run_test "Parse @include directive" "directive:include" "$result"
run_test "Parse include target" "target:common-auth" "$result"

# Test 5: Complex control flags
echo ""
echo "Testing complex control flags..."
result=$(parse_pam_line "auth    [success=1 default=ignore]  pam_succeed_if.so")
run_test "Parse complex control flag" "control_flag:[success=1 default=ignore]" "$result"

# Test 6: Validate syntax
echo ""
echo "Testing syntax validation..."
validate_pam_syntax "auth required pam_unix.so" && valid_syntax="valid" || valid_syntax="invalid"
run_test "Valid syntax passes" "valid" "$valid_syntax"

validate_result=$(validate_pam_syntax "invalid_type required pam_unix.so" 2>&1)
run_test "Invalid module type detected" "Invalid module type" "$validate_result"

validate_result=$(validate_pam_syntax "auth invalid_flag pam_unix.so" 2>&1)
run_test "Invalid control flag detected" "Invalid control flag" "$validate_result"

# Test 7: File parsing
echo ""
echo "Testing file parsing..."
TEST_FILE="/tmp/test_pam"
cat >"$TEST_FILE" <<EOF
# Test PAM file
auth    required    pam_env.so
auth    sufficient  pam_u2f.so
auth    required    pam_unix.so
account required    pam_unix.so
EOF

file_result=$(parse_pam_file "$TEST_FILE")
run_test "Parse file - count lines" "total_lines:5" "$file_result"
run_test "Parse file - detect U2F" "u2f_module_found:true" "$file_result"
run_test "Parse file - count auth lines" "auth_lines:3" "$file_result"

# Test 8: Find insertion point
echo ""
echo "Testing insertion point detection..."
insertion_point=$(find_insertion_point "$TEST_FILE")
# The test file has pam_env.so on line 2, so insertion should be line 3
run_test "Find insertion after pam_env" "3" "$insertion_point"

# Clean up
rm -f "$TEST_FILE"

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

#!/bin/bash

# Test runner for Yubikey PAM Installer
# This script runs all available test suites

set -e

cd "$(dirname "$0")"

echo "==================================="
echo "Yubikey PAM Installer Test Suite"
echo "==================================="

# Track overall test results
OVERALL_RESULT=0

# Make all scripts executable
chmod +x src/*.sh 2>/dev/null || true
chmod +x simple_*.sh 2>/dev/null || true
chmod +x demo_*.sh 2>/dev/null || true

# Function to run a test and track results
run_test() {
  local test_name="$1"
  local test_command="$2"
  
  echo ""
  echo "Running $test_name..."
  echo "-----------------------------------"
  
  if eval "$test_command"; then
    echo "✓ $test_name passed"
  else
    echo "✗ $test_name failed"
    OVERALL_RESULT=1
  fi
}

# Run simple tests (no dependencies required)
if [ -f "./simple_test.sh" ]; then
  run_test "Simple Parser Tests" "./simple_test.sh"
fi

if [ -f "./simple_backup_test.sh" ]; then
  run_test "Simple Backup Tests" "./simple_backup_test.sh"
fi

if [ -f "./simple_registration_test.sh" ]; then
  run_test "Simple Registration Tests" "./simple_registration_test.sh"
fi

# Run bats tests if available
if command -v bats &> /dev/null; then
  echo ""
  echo "Running BATS Test Suites..."
  echo "-----------------------------------"
  
  if [ -d tests ]; then
    for test_file in tests/*.bats; do
      if [ -f "$test_file" ]; then
        test_name=$(basename "$test_file" .bats)
        run_test "BATS $test_name" "bats '$test_file'"
      fi
    done
  else
    echo "Warning: tests directory not found, skipping BATS tests"
  fi
else
  echo ""
  echo "Note: BATS not installed, skipping BATS test suites"
  echo "To install: apt-get install bats"
fi

echo ""
echo "==================================="
echo "Test Results Summary"
echo "==================================="

# Check if all tests passed
if [ $OVERALL_RESULT -eq 0 ]; then
  echo "✓ All tests passed successfully!"
  exit 0
else
  echo "✗ Some tests failed. Please review the output above."
  exit 1
fi
#!/bin/bash

# Test runner for Yubikey PAM Installer

set -e

echo "==================================="
echo "Yubikey PAM Installer Test Suite"
echo "==================================="
echo ""

# Check if bats is installed
if ! command -v bats &> /dev/null; then
  echo "Error: bats is not installed."
  echo "Please install bats (Bash Automated Testing System)"
  echo ""
  echo "On Ubuntu/Debian: sudo apt-get install bats"
  echo "On Fedora: sudo dnf install bats"
  echo "On macOS: brew install bats-core"
  exit 1
fi

# Make parser script executable
chmod +x src/pam_parser.sh

# Run tests
echo "Running PAM Parser Tests..."
echo "-----------------------------------"
bats tests/test_pam_parser.bats

echo ""
echo "==================================="
echo "Test Results Summary"
echo "==================================="

# Check if all tests passed
if [ $? -eq 0 ]; then
  echo "✓ All tests passed successfully!"
else
  echo "✗ Some tests failed. Please review the output above."
  exit 1
fi
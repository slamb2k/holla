#!/bin/bash

# Demo script for PAM parser functionality

source src/pam_parser.sh

# Create demo PAM file
DEMO_FILE="/tmp/demo_pam_sudo"

cat > "$DEMO_FILE" <<'EOF'
# PAM configuration for sudo service
# This is a typical sudo PAM configuration

auth       required   pam_env.so
auth       required   pam_unix.so nullok_secure
account    required   pam_unix.so
password   required   pam_unix.so obscure sha512
session    required   pam_unix.so
session    optional   pam_umask.so
EOF

echo "==================================="
echo "PAM Parser Demonstration"
echo "==================================="
echo ""

echo "1. Parsing a sample PAM file:"
echo "-----------------------------------"
parse_pam_file "$DEMO_FILE"
echo ""

echo "2. Validating PAM syntax:"
echo "-----------------------------------"
validate_pam_file "$DEMO_FILE"
echo ""

echo "3. Analyzing PAM structure:"
echo "-----------------------------------"
analyze_pam_structure "$DEMO_FILE"
echo ""

echo "4. Testing U2F module detection:"
echo "-----------------------------------"
TEST_LINE="auth sufficient pam_u2f.so authfile=/etc/u2f_keys"
echo "Testing line: $TEST_LINE"
if has_u2f_module "$TEST_LINE"; then
  echo "✓ U2F module detected"
else
  echo "✗ No U2F module found"
fi
echo ""

echo "5. Parsing individual lines:"
echo "-----------------------------------"
echo "Parsing: auth required pam_unix.so nullok"
parse_pam_line "auth required pam_unix.so nullok"
echo ""

# Clean up
rm -f "$DEMO_FILE"

echo "==================================="
echo "Demo completed successfully!"
echo "====================================="
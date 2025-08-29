#!/usr/bin/env bats

# Test suite for PAM configuration parser

setup() {
  # Source the parser functions
  source "${BATS_TEST_DIRNAME}/../src/pam_parser.sh"
  
  # Create temp directory for test files
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
}

teardown() {
  # Clean up test directory
  rm -rf "$TEST_DIR"
}

# Test: Valid PAM line parsing
@test "parse valid PAM auth line" {
  line="auth    required    pam_unix.so nullok try_first_pass"
  run parse_pam_line "$line"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "module_type:auth" ]]
  [[ "${output}" =~ "control_flag:required" ]]
  [[ "${output}" =~ "module_path:pam_unix.so" ]]
  [[ "${output}" =~ "module_args:nullok try_first_pass" ]]
}

@test "parse valid PAM account line" {
  line="account sufficient  pam_succeed_if.so uid >= 1000 quiet"
  run parse_pam_line "$line"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "module_type:account" ]]
  [[ "${output}" =~ "control_flag:sufficient" ]]
}

@test "parse valid PAM password line" {
  line="password  requisite   pam_pwquality.so retry=3"
  run parse_pam_line "$line"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "module_type:password" ]]
  [[ "${output}" =~ "control_flag:requisite" ]]
}

@test "parse valid PAM session line" {
  line="session optional    pam_keyinit.so revoke"
  run parse_pam_line "$line"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "module_type:session" ]]
}

# Test: Complex control flags
@test "parse complex control flag with brackets" {
  line="auth    [success=1 default=ignore]  pam_succeed_if.so"
  run parse_pam_line "$line"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "control_flag:[success=1 default=ignore]" ]]
}

# Test: Comments and blank lines
@test "detect comment line" {
  run is_comment_or_blank "# This is a comment"
  [ "$status" -eq 0 ]
}

@test "detect blank line" {
  run is_comment_or_blank "   "
  [ "$status" -eq 0 ]
}

@test "reject non-comment line" {
  run is_comment_or_blank "auth required pam_unix.so"
  [ "$status" -eq 1 ]
}

# Test: Include directives
@test "parse include directive" {
  line="@include common-auth"
  run parse_pam_line "$line"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "directive:include" ]]
  [[ "${output}" =~ "target:common-auth" ]]
}

@test "parse substack directive" {
  line="auth    substack    common-auth"
  run parse_pam_line "$line"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "module_type:auth" ]]
  [[ "${output}" =~ "control_flag:substack" ]]
  [[ "${output}" =~ "module_path:common-auth" ]]
}

# Test: Invalid syntax detection
@test "detect invalid module type" {
  line="invalid required pam_unix.so"
  run validate_pam_syntax "$line"
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "Invalid module type" ]]
}

@test "detect invalid control flag" {
  line="auth invalid_flag pam_unix.so"
  run validate_pam_syntax "$line"
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "Invalid control flag" ]]
}

@test "detect missing module path" {
  line="auth required"
  run validate_pam_syntax "$line"
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "Missing module path" ]]
}

# Test: Module detection
@test "detect pam_u2f module" {
  line="auth sufficient pam_u2f.so authfile=/etc/u2f_keys"
  run has_u2f_module "$line"
  [ "$status" -eq 0 ]
}

@test "detect pam_yubico module" {
  line="auth required pam_yubico.so mode=challenge-response"
  run has_u2f_module "$line"
  [ "$status" -eq 0 ]
}

@test "no u2f module in regular line" {
  line="auth required pam_unix.so"
  run has_u2f_module "$line"
  [ "$status" -eq 1 ]
}

# Test: Find insertion point
@test "find insertion point after pam_env" {
  cat > "$TEST_DIR/test-auth" <<EOF
auth    required    pam_env.so
auth    required    pam_unix.so
auth    optional    pam_cap.so
EOF
  
  run find_insertion_point "$TEST_DIR/test-auth"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]  # Line number after pam_env
}

@test "find insertion point when no pam_env" {
  cat > "$TEST_DIR/test-auth" <<EOF
# PAM configuration
auth    required    pam_unix.so
auth    optional    pam_cap.so
EOF
  
  run find_insertion_point "$TEST_DIR/test-auth"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]  # Before pam_unix
}

# Test: Full file parsing
@test "parse complete PAM file" {
  cat > "$TEST_DIR/test-sudo" <<EOF
# PAM configuration for sudo
auth       required   pam_env.so
auth       sufficient pam_u2f.so
auth       required   pam_unix.so
account    required   pam_unix.so
password   required   pam_unix.so
session    required   pam_unix.so
EOF
  
  run parse_pam_file "$TEST_DIR/test-sudo"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "u2f_module_found:true" ]]
  [[ "${output}" =~ "total_lines:7" ]]
}

# Test: Validate entire PAM configuration
@test "validate valid PAM configuration" {
  cat > "$TEST_DIR/valid-config" <<EOF
auth    required    pam_env.so
auth    required    pam_unix.so nullok
account required    pam_unix.so
password required   pam_unix.so sha512
session  required   pam_unix.so
EOF
  
  run validate_pam_file "$TEST_DIR/valid-config"
  [ "$status" -eq 0 ]
}

@test "validate invalid PAM configuration" {
  cat > "$TEST_DIR/invalid-config" <<EOF
auth    required    pam_env.so
invalid_type required pam_unix.so
auth    bad_flag    pam_unix.so
EOF
  
  run validate_pam_file "$TEST_DIR/invalid-config"
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "error" ]]
}
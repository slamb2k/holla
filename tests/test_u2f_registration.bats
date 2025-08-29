#!/usr/bin/env bats

# Test suite for U2F Registration Tool

setup() {
  # Source the registration functions
  source "${BATS_TEST_DIRNAME}/../src/u2f_registration.sh"
  
  # Create temp directory for testing
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
  export TEST_HOME="$TEST_DIR/home"
  export TEST_CONFIG_DIR="$TEST_HOME/.config/Yubico"
  export TEST_U2F_KEYS_FILE="$TEST_CONFIG_DIR/u2f_keys"
  
  # Create mock home directory
  mkdir -p "$TEST_HOME"
  
  # Override HOME for testing
  export ORIGINAL_HOME="$HOME"
  export HOME="$TEST_HOME"
}

teardown() {
  # Restore original HOME
  export HOME="$ORIGINAL_HOME"
  
  # Clean up test directory
  rm -rf "$TEST_DIR"
}

# Test: Check for pamu2fcfg installation
@test "detect pamu2fcfg installation" {
  # Mock which command to simulate pamu2fcfg installed
  which() { echo "/usr/bin/pamu2fcfg"; }
  export -f which
  
  run check_pamu2fcfg_installed
  [ "$status" -eq 0 ]
}

@test "detect missing pamu2fcfg" {
  # Mock which command to simulate pamu2fcfg not installed
  which() { return 1; }
  export -f which
  
  run check_pamu2fcfg_installed
  [ "$status" -eq 1 ]
  [[ "$output" =~ "pamu2fcfg is not installed" ]]
}

# Test: Suggest installation command
@test "suggest apt installation for Debian/Ubuntu" {
  # Mock lsb_release for Ubuntu
  lsb_release() {
    case "$1" in
      -si) echo "Ubuntu" ;;
      *) echo "20.04" ;;
    esac
  }
  export -f lsb_release
  
  run get_install_command
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apt-get install" ]]
  [[ "$output" =~ "libpam-u2f" ]]
}

@test "suggest dnf installation for Fedora" {
  # Mock detection for Fedora
  command() {
    [[ "$2" == "dnf" ]] && return 0
    return 1
  }
  export -f command
  
  run get_install_command
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dnf install" ]]
}

@test "suggest pacman installation for Arch" {
  # Mock detection for Arch
  command() {
    [[ "$2" == "pacman" ]] && return 0
    return 1
  }
  export -f command
  
  run get_install_command
  [ "$status" -eq 0 ]
  [[ "$output" =~ "pacman -S" ]]
}

# Test: Create Yubico directory structure
@test "create .config/Yubico directory" {
  run create_yubico_directory "$TEST_HOME"
  [ "$status" -eq 0 ]
  [ -d "$TEST_CONFIG_DIR" ]
}

@test "set correct directory permissions" {
  create_yubico_directory "$TEST_HOME"
  
  # Check directory permissions (should be 700)
  perms=$(stat -c %a "$TEST_CONFIG_DIR")
  [ "$perms" = "700" ]
}

@test "handle existing directory gracefully" {
  mkdir -p "$TEST_CONFIG_DIR"
  touch "$TEST_U2F_KEYS_FILE"
  
  run create_yubico_directory "$TEST_HOME"
  [ "$status" -eq 0 ]
  [ -f "$TEST_U2F_KEYS_FILE" ]  # File should still exist
}

# Test: U2F key file management
@test "create new u2f_keys file" {
  create_yubico_directory "$TEST_HOME"
  
  run init_u2f_keys_file "$TEST_U2F_KEYS_FILE"
  [ "$status" -eq 0 ]
  [ -f "$TEST_U2F_KEYS_FILE" ]
}

@test "set correct file permissions (0600)" {
  create_yubico_directory "$TEST_HOME"
  init_u2f_keys_file "$TEST_U2F_KEYS_FILE"
  
  perms=$(stat -c %a "$TEST_U2F_KEYS_FILE")
  [ "$perms" = "600" ]
}

@test "preserve existing keys during init" {
  create_yubico_directory "$TEST_HOME"
  echo "testuser:existing_key_data" > "$TEST_U2F_KEYS_FILE"
  
  run init_u2f_keys_file "$TEST_U2F_KEYS_FILE"
  [ "$status" -eq 0 ]
  grep -q "existing_key_data" "$TEST_U2F_KEYS_FILE"
}

# Test: Parse pamu2fcfg output
@test "parse valid pamu2fcfg output" {
  mock_output="testuser:credential_data:key_handle_data"
  
  run parse_pamu2fcfg_output "$mock_output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "credential:credential_data" ]]
  [[ "$output" =~ "key_handle:key_handle_data" ]]
}

@test "validate pamu2fcfg output format" {
  invalid_output="invalid_format"
  
  run validate_u2f_registration "$invalid_output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid registration format" ]]
}

# Test: Add key to file
@test "add first key to empty file" {
  create_yubico_directory "$TEST_HOME"
  touch "$TEST_U2F_KEYS_FILE"
  
  registration="testuser:credential1:handle1"
  run add_key_to_file "$TEST_U2F_KEYS_FILE" "$registration" "testuser"
  [ "$status" -eq 0 ]
  
  content=$(cat "$TEST_U2F_KEYS_FILE")
  [[ "$content" == "$registration" ]]
}

@test "append additional key for same user" {
  create_yubico_directory "$TEST_HOME"
  echo "testuser:credential1:handle1" > "$TEST_U2F_KEYS_FILE"
  
  registration="credential2:handle2"
  run add_key_to_file "$TEST_U2F_KEYS_FILE" "$registration" "testuser"
  [ "$status" -eq 0 ]
  
  content=$(cat "$TEST_U2F_KEYS_FILE")
  [[ "$content" =~ "credential1:handle1:credential2:handle2" ]]
}

@test "add key for different user" {
  create_yubico_directory "$TEST_HOME"
  echo "user1:credential1:handle1" > "$TEST_U2F_KEYS_FILE"
  
  registration="user2:credential2:handle2"
  run add_key_to_file "$TEST_U2F_KEYS_FILE" "$registration" "user2"
  [ "$status" -eq 0 ]
  
  # Both users should be in file
  grep -q "user1:" "$TEST_U2F_KEYS_FILE"
  grep -q "user2:" "$TEST_U2F_KEYS_FILE"
}

# Test: Check for existing keys
@test "detect existing key for user" {
  create_yubico_directory "$TEST_HOME"
  echo "testuser:credential1:handle1" > "$TEST_U2F_KEYS_FILE"
  
  run check_existing_keys "$TEST_U2F_KEYS_FILE" "testuser"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "found" ]]
}

@test "detect no existing keys" {
  create_yubico_directory "$TEST_HOME"
  touch "$TEST_U2F_KEYS_FILE"
  
  run check_existing_keys "$TEST_U2F_KEYS_FILE" "testuser"
  [ "$status" -eq 1 ]
}

# Test: User feedback
@test "display touch prompt" {
  run show_touch_prompt
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Touch your Yubikey" ]]
}

@test "display success message" {
  run show_registration_success
  [ "$status" -eq 0 ]
  [[ "$output" =~ "successfully registered" ]]
}

@test "display timeout message" {
  run show_timeout_message
  [ "$status" -eq 0 ]
  [[ "$output" =~ "timeout" ]] || [[ "$output" =~ "Timeout" ]]
}

# Test: Mock registration workflow
@test "simulate successful registration" {
  create_yubico_directory "$TEST_HOME"
  
  # Mock pamu2fcfg command
  pamu2fcfg() {
    echo "testuser:mock_credential:mock_handle"
    return 0
  }
  export -f pamu2fcfg
  
  run register_yubikey_mock "testuser" "$TEST_U2F_KEYS_FILE"
  [ "$status" -eq 0 ]
  [ -f "$TEST_U2F_KEYS_FILE" ]
  grep -q "mock_credential" "$TEST_U2F_KEYS_FILE"
}

@test "handle registration timeout" {
  # Mock pamu2fcfg with timeout
  pamu2fcfg() {
    return 124  # Timeout exit code
  }
  export -f pamu2fcfg
  
  run register_yubikey_mock "testuser" "$TEST_U2F_KEYS_FILE"
  [ "$status" -eq 124 ]
  [[ "$output" =~ "timeout" ]] || [[ "$output" =~ "Timeout" ]]
}

@test "handle device not found" {
  # Mock pamu2fcfg with device error
  pamu2fcfg() {
    echo "No U2F device found" >&2
    return 1
  }
  export -f pamu2fcfg
  
  run register_yubikey_mock "testuser" "$TEST_U2F_KEYS_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "device" ]] || [[ "$output" =~ "Device" ]]
}

# Test: Backup before modification
@test "create backup before adding key" {
  create_yubico_directory "$TEST_HOME"
  echo "original_content" > "$TEST_U2F_KEYS_FILE"
  
  run backup_u2f_keys "$TEST_U2F_KEYS_FILE"
  [ "$status" -eq 0 ]
  [ -f "$TEST_U2F_KEYS_FILE.backup" ]
  
  backup_content=$(cat "$TEST_U2F_KEYS_FILE.backup")
  [[ "$backup_content" == "original_content" ]]
}

# Test: List registered keys
@test "list keys for user" {
  create_yubico_directory "$TEST_HOME"
  echo "testuser:cred1:handle1:cred2:handle2" > "$TEST_U2F_KEYS_FILE"
  
  run list_user_keys "$TEST_U2F_KEYS_FILE" "testuser"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2 key(s) registered" ]]
}

@test "show no keys message" {
  create_yubico_directory "$TEST_HOME"
  touch "$TEST_U2F_KEYS_FILE"
  
  run list_user_keys "$TEST_U2F_KEYS_FILE" "testuser"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No keys registered" ]]
}
#!/bin/bash

# Demo script for U2F Registration functionality

source src/u2f_registration.sh

# Demo directory setup
DEMO_DIR="/tmp/yubikey_registration_demo"
DEMO_HOME="$DEMO_DIR/home"
DEMO_CONFIG_DIR="$DEMO_HOME/.config/Yubico"
DEMO_U2F_KEYS_FILE="$DEMO_CONFIG_DIR/u2f_keys"

# Save original HOME
ORIGINAL_HOME="$HOME"

# Cleanup function
cleanup() {
  export HOME="$ORIGINAL_HOME"
  echo ""
  echo "Cleaning up demo files..."
  rm -rf "$DEMO_DIR"
}
trap cleanup EXIT

# Setup demo environment
setup_demo() {
  mkdir -p "$DEMO_HOME"
  export HOME="$DEMO_HOME"
}

# Mock pamu2fcfg for demonstration
mock_pamu2fcfg() {
  local user="$1"
  local existing="$2"
  
  # Simulate touch delay
  echo "Waiting for touch..."
  sleep 2
  
  # Generate mock credential data
  local timestamp
  timestamp=$(date +%s)
  local mock_cred="MockCredential_${timestamp}"
  local mock_handle="MockHandle_${timestamp}"
  
  if [[ -n "$existing" ]]; then
    # Additional key format (without username prefix)
    echo "${mock_cred}:${mock_handle}"
  else
    # First key format
    echo "${user}:${mock_cred}:${mock_handle}"
  fi
  
  return 0
}

echo "==================================="
echo "U2F Registration System Demo"
echo "==================================="
echo ""

echo "Setting up demo environment..."
setup_demo
echo "✓ Demo environment ready"
echo ""

echo "1. Checking for pamu2fcfg installation"
echo "-----------------------------------"
# Override which for demo
which() {
  if [[ "$1" == "pamu2fcfg" ]]; then
    echo "/usr/bin/pamu2fcfg"
    return 0
  fi
  command which "$1"
}

if check_pamu2fcfg_installed; then
  echo "✓ pamu2fcfg is installed (mocked)"
else
  echo "✗ pamu2fcfg not found"
fi
echo ""

echo "2. Getting installation command for current system"
echo "-----------------------------------"
echo "Install command: $(get_install_command)"
echo ""

echo "3. Creating Yubico directory structure"
echo "-----------------------------------"
create_yubico_directory "$DEMO_HOME"
echo "Directory created with permissions: $(stat -c %a "$DEMO_CONFIG_DIR")"
echo ""

echo "4. Initializing U2F keys file"
echo "-----------------------------------"
init_u2f_keys_file "$DEMO_U2F_KEYS_FILE"
echo "File created with permissions: $(stat -c %a "$DEMO_U2F_KEYS_FILE")"
echo ""

echo "5. Simulating first key registration"
echo "-----------------------------------"
echo "Registering key for user: demo_user"

# Override pamu2fcfg for demo
pamu2fcfg() {
  case "$2" in
    demo_user)
      mock_pamu2fcfg "$2" ""
      ;;
    *)
      mock_pamu2fcfg "unknown" ""
      ;;
  esac
}
export -f pamu2fcfg

# Simulate registration
registration_output=$(pamu2fcfg -u demo_user)
echo "Mock device response received:"
echo "  $registration_output"
echo ""

# Add to file
add_key_to_file "$DEMO_U2F_KEYS_FILE" "$registration_output" "demo_user"
echo "✓ First key registered"
echo ""

echo "6. Checking existing keys"
echo "-----------------------------------"
if check_existing_keys "$DEMO_U2F_KEYS_FILE" "demo_user"; then
  echo "Keys found in file"
fi
echo ""
list_user_keys "$DEMO_U2F_KEYS_FILE" "demo_user"
echo ""

echo "7. Simulating additional key registration"
echo "-----------------------------------"
echo "Adding second key for demo_user..."

# Simulate second key with -n flag
pamu2fcfg() {
  case "$2" in
    demo_user)
      # Check if -n flag is present (additional key)
      if [[ "$3" == "-n" ]]; then
        mock_pamu2fcfg "$2" "existing"
      else
        mock_pamu2fcfg "$2" ""
      fi
      ;;
  esac
}
export -f pamu2fcfg

# Get existing keys for -n flag
existing_line=$(grep "^demo_user:" "$DEMO_U2F_KEYS_FILE" | cut -d: -f2-)
second_key_output=$(pamu2fcfg -u demo_user -n "$existing_line")
echo "Mock device response received:"
echo "  $second_key_output"
echo ""

# Add second key
add_key_to_file "$DEMO_U2F_KEYS_FILE" "$second_key_output" "demo_user"
echo "✓ Second key registered"
echo ""

list_user_keys "$DEMO_U2F_KEYS_FILE" "demo_user"
echo ""

echo "8. Creating backup"
echo "-----------------------------------"
backup_u2f_keys "$DEMO_U2F_KEYS_FILE"
echo ""

echo "9. Displaying final keys file content"
echo "-----------------------------------"
echo "Content of $DEMO_U2F_KEYS_FILE:"
echo ""
cat "$DEMO_U2F_KEYS_FILE" | while IFS=: read -r user rest; do
  echo "User: $user"
  # Count and display keys
  key_count=0
  while IFS=: read -r cred handle remaining; do
    ((key_count++))
    echo "  Key #$key_count:"
    echo "    Credential: ${cred:0:20}..."
    echo "    Handle: ${handle:0:20}..."
    if [[ -n "$remaining" ]]; then
      # Parse additional keys
      echo "$remaining" | tr ':' '\n' | paste -d: - - | while IFS=: read -r c h; do
        ((key_count++))
        echo "  Key #$key_count:"
        echo "    Credential: ${c:0:20}..."
        echo "    Handle: ${h:0:20}..."
      done
    fi
    break
  done <<< "$rest"
done
echo ""

echo "10. Testing user feedback displays"
echo "-----------------------------------"
show_touch_prompt
echo ""
show_registration_success
echo ""

echo "==================================="
echo "Demo completed successfully!"
echo ""
echo "Key Features Demonstrated:"
echo "  ✓ Directory and file creation with proper permissions"
echo "  ✓ First key registration"
echo "  ✓ Additional key registration"
echo "  ✓ Key listing and counting"
echo "  ✓ Backup creation"
echo "  ✓ User feedback displays"
echo "====================================="
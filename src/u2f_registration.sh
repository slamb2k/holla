#!/bin/bash

# U2F Registration Tool for Yubikey PAM Integration
# Provides functions to register Yubikey devices for U2F authentication

# Color codes for user feedback
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default paths
readonly DEFAULT_CONFIG_DIR="$HOME/.config/Yubico"
readonly DEFAULT_U2F_KEYS_FILE="$DEFAULT_CONFIG_DIR/u2f_keys"
# System-wide keys file (for future use)
# readonly SYSTEM_U2F_KEYS_FILE="/etc/u2f_keys"

# Timeout for Yubikey touch (in seconds)
readonly TOUCH_TIMEOUT=30

# Function: Check if pamu2fcfg is installed
# Returns: 0 if installed, 1 if not
check_pamu2fcfg_installed() {
  if which pamu2fcfg >/dev/null 2>&1; then
    return 0
  else
    echo "Error: pamu2fcfg is not installed" >&2
    echo "This tool is required for U2F registration" >&2
    return 1
  fi
}

# Function: Get installation command for current distribution
# Outputs: Installation command for pamu2fcfg
# Returns: 0 on success
get_install_command() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "sudo apt-get install libpam-u2f pamu2fcfg"
  elif command -v dnf >/dev/null 2>&1; then
    echo "sudo dnf install pam-u2f pamu2fcfg"
  elif command -v yum >/dev/null 2>&1; then
    echo "sudo yum install pam-u2f pamu2fcfg"
  elif command -v pacman >/dev/null 2>&1; then
    echo "sudo pacman -S pam-u2f"
  elif command -v zypper >/dev/null 2>&1; then
    echo "sudo zypper install pam_u2f"
  else
    echo "Please install pam-u2f and pamu2fcfg using your distribution's package manager"
  fi

  return 0
}

# Function: Create Yubico directory structure
# Arguments: $1 - Home directory (optional)
# Returns: 0 on success, 1 on error
create_yubico_directory() {
  local home_dir="${1:-$HOME}"
  local config_dir="$home_dir/.config/Yubico"

  # Create directory if it doesn't exist
  if [[ ! -d "$config_dir" ]]; then
    if mkdir -p "$config_dir"; then
      chmod 700 "$config_dir"
      echo "Created directory: $config_dir"
    else
      echo "Error: Failed to create directory: $config_dir" >&2
      return 1
    fi
  fi

  return 0
}

# Function: Initialize u2f_keys file
# Arguments: $1 - Path to u2f_keys file
# Returns: 0 on success
init_u2f_keys_file() {
  local keys_file="${1:-$DEFAULT_U2F_KEYS_FILE}"

  # Create file if it doesn't exist
  if [[ ! -f "$keys_file" ]]; then
    touch "$keys_file"
    chmod 600 "$keys_file"
    echo "Created U2F keys file: $keys_file"
  else
    # Ensure correct permissions on existing file
    chmod 600 "$keys_file"
  fi

  return 0
}

# Function: Parse pamu2fcfg output
# Arguments: $1 - pamu2fcfg output
# Outputs: Parsed registration data
# Returns: 0 on success, 1 on error
parse_pamu2fcfg_output() {
  local output="$1"

  if [[ -z "$output" ]]; then
    echo "Error: Empty registration output" >&2
    return 1
  fi

  # pamu2fcfg output format: username:credential:key_handle
  if [[ "$output" =~ ^([^:]+):([^:]+):([^:]+)$ ]]; then
    local username="${BASH_REMATCH[1]}"
    local credential="${BASH_REMATCH[2]}"
    local key_handle="${BASH_REMATCH[3]}"

    echo "username:$username"
    echo "credential:$credential"
    echo "key_handle:$key_handle"
    return 0
  else
    echo "Error: Invalid pamu2fcfg output format" >&2
    return 1
  fi
}

# Function: Validate U2F registration format
# Arguments: $1 - Registration string
# Returns: 0 if valid, 1 if invalid
validate_u2f_registration() {
  local registration="$1"

  # Check for minimum format: username:credential:handle
  if [[ "$registration" =~ ^[^:]+:[^:]+:[^:]+$ ]]; then
    return 0
  else
    echo "Error: Invalid registration format" >&2
    return 1
  fi
}

# Function: Check for existing keys
# Arguments: $1 - u2f_keys file, $2 - username
# Returns: 0 if keys exist, 1 if not
check_existing_keys() {
  local keys_file="$1"
  local username="$2"

  if [[ ! -f "$keys_file" ]]; then
    return 1
  fi

  if grep -q "^$username:" "$keys_file" 2>/dev/null; then
    local key_count
    key_count=$(grep "^$username:" "$keys_file" | tr ':' '\n' | wc -l)
    key_count=$((key_count - 1)) # Subtract username from count
    key_count=$((key_count / 2)) # Each key has credential and handle
    echo "User $username has $key_count key(s) found"
    return 0
  else
    return 1
  fi
}

# Function: Add key to file
# Arguments: $1 - u2f_keys file, $2 - registration data, $3 - username
# Returns: 0 on success, 1 on error
add_key_to_file() {
  local keys_file="$1"
  local registration="$2"
  local username="$3"

  # Check if user already has keys
  if grep -q "^$username:" "$keys_file" 2>/dev/null; then
    # Append to existing line
    local existing_line
    existing_line=$(grep "^$username:" "$keys_file")
    local new_line="$existing_line:$registration"

    # Replace the line
    local temp_file
    temp_file=$(mktemp)
    grep -v "^$username:" "$keys_file" >"$temp_file"
    echo "$new_line" >>"$temp_file"
    mv "$temp_file" "$keys_file"
    chmod 600 "$keys_file"
  else
    # Add new line for user
    if [[ "$registration" =~ ^$username: ]]; then
      echo "$registration" >>"$keys_file"
    else
      echo "$username:$registration" >>"$keys_file"
    fi
    chmod 600 "$keys_file"
  fi

  return 0
}

# Function: Show touch prompt
# Returns: 0
show_touch_prompt() {
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}⚡ Touch your Yubikey to register ⚡${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "The Yubikey LED should be blinking."
  echo "Touch the metal contact to complete registration..."
  echo ""
  return 0
}

# Function: Show registration success
# Returns: 0
show_registration_success() {
  echo ""
  echo -e "${GREEN}✓ Yubikey successfully registered!${NC}"
  return 0
}

# Function: Show timeout message
# Returns: 0
show_timeout_message() {
  echo ""
  echo -e "${RED}✗ Registration timeout - no touch detected${NC}"
  echo "Please try again and touch the Yubikey when it blinks"
  return 0
}

# Function: Backup U2F keys file
# Arguments: $1 - u2f_keys file path
# Returns: 0 on success
backup_u2f_keys() {
  local keys_file="$1"

  if [[ -f "$keys_file" ]]; then
    local backup_file="$keys_file.backup"
    cp "$keys_file" "$backup_file"
    chmod 600 "$backup_file"
    echo "Backup created: $backup_file"
  fi

  return 0
}

# Function: List user's registered keys
# Arguments: $1 - u2f_keys file, $2 - username
# Returns: 0
list_user_keys() {
  local keys_file="$1"
  local username="$2"

  if [[ ! -f "$keys_file" ]]; then
    echo "No keys file found"
    return 0
  fi

  if grep -q "^$username:" "$keys_file" 2>/dev/null; then
    local line
    line=$(grep "^$username:" "$keys_file")
    # Count credentials (every odd field after username)
    local key_count
    key_count=$(echo "$line" | tr ':' '\n' | wc -l)
    key_count=$((key_count - 1)) # Subtract username
    key_count=$((key_count / 2)) # Each key has credential and handle

    echo -e "${GREEN}$key_count key(s) registered for user $username${NC}"

    # Display key numbers
    for i in $(seq 1 $key_count); do
      echo "  - Key #$i"
    done
  else
    echo "No keys registered for user $username"
  fi

  return 0
}

# Function: Mock registration for testing
# Arguments: $1 - username, $2 - u2f_keys file
# Returns: pamu2fcfg exit code
register_yubikey_mock() {
  local username="$1"
  local keys_file="$2"

  # Call mocked pamu2fcfg
  local output
  output=$(pamu2fcfg -u "$username" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    if validate_u2f_registration "$output"; then
      add_key_to_file "$keys_file" "$output" "$username"
      return 0
    else
      echo "Invalid registration format" >&2
      return 1
    fi
  elif [[ $exit_code -eq 124 ]]; then
    show_timeout_message
    return 124
  else
    echo "$output" >&2
    return $exit_code
  fi
}

# Function: Register a Yubikey (main function)
# Arguments: $1 - username (optional, defaults to current user)
# Returns: 0 on success, 1 on error
register_yubikey() {
  local username="${1:-$USER}"
  local keys_file="$DEFAULT_U2F_KEYS_FILE"

  echo "==================================="
  echo "    Yubikey U2F Registration"
  echo "==================================="
  echo ""

  # Check if pamu2fcfg is installed
  if ! check_pamu2fcfg_installed; then
    echo ""
    echo "To install the required tools, run:"
    get_install_command
    return 1
  fi

  # Create directory structure
  if ! create_yubico_directory; then
    return 1
  fi

  # Initialize keys file
  init_u2f_keys_file "$keys_file"

  # Check for existing keys
  echo "Checking for existing keys..."
  if check_existing_keys "$keys_file" "$username"; then
    echo ""
    read -p "Add another key? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Registration cancelled"
      return 0
    fi
  else
    echo "No existing keys found for user $username"
  fi

  # Backup existing keys
  if [[ -f "$keys_file" ]] && [[ -s "$keys_file" ]]; then
    backup_u2f_keys "$keys_file"
  fi

  echo ""
  echo "Please insert your Yubikey and press Enter to continue..."
  read -r

  # Show touch prompt
  show_touch_prompt

  # Run pamu2fcfg with timeout
  local registration_output
  local pamu2fcfg_cmd="pamu2fcfg -u $username"

  # For additional keys, use -n flag
  if check_existing_keys "$keys_file" "$username" >/dev/null 2>&1; then
    # Get existing registration for -n flag
    local existing_line
    existing_line=$(grep "^$username:" "$keys_file")
    # Remove username prefix
    existing_line=${existing_line#$username:}
    pamu2fcfg_cmd="pamu2fcfg -u $username -n $existing_line"
  fi

  # Execute with timeout
  if command -v timeout >/dev/null 2>&1; then
    registration_output=$(timeout $TOUCH_TIMEOUT $pamu2fcfg_cmd 2>&1)
  else
    registration_output=$($pamu2fcfg_cmd 2>&1)
  fi

  local exit_code=$?

  # Handle registration result
  if [[ $exit_code -eq 0 ]]; then
    # Validate output format
    if validate_u2f_registration "$registration_output"; then
      # Add to keys file
      if check_existing_keys "$keys_file" "$username" >/dev/null 2>&1; then
        # For additional keys, extract just the new credential:handle
        local new_key=${registration_output#$username:}
        add_key_to_file "$keys_file" "$new_key" "$username"
      else
        # For first key, add complete line
        add_key_to_file "$keys_file" "$registration_output" "$username"
      fi

      show_registration_success
      echo ""
      echo "Registration saved to: $keys_file"
      echo ""

      # Show registered keys
      list_user_keys "$keys_file" "$username"

      return 0
    else
      echo -e "${RED}✗ Registration failed: Invalid format${NC}" >&2
      echo "Output: $registration_output" >&2
      return 1
    fi
  elif [[ $exit_code -eq 124 ]]; then
    show_timeout_message
    return 1
  else
    echo -e "${RED}✗ Registration failed${NC}" >&2

    # Parse error message
    if [[ "$registration_output" =~ "No U2F device" ]] || [[ "$registration_output" =~ "No device found" ]]; then
      echo "No Yubikey detected. Please ensure your Yubikey is inserted."
    elif [[ "$registration_output" =~ "Permission denied" ]]; then
      echo "Permission denied. You may need to configure udev rules for Yubikey access."
      echo "See: https://support.yubico.com/hc/en-us/articles/360013708900"
    else
      echo "Error: $registration_output"
    fi

    return 1
  fi
}

# Function: Interactive registration wizard
# Returns: 0 on success
registration_wizard() {
  clear
  echo "╔════════════════════════════════════╗"
  echo "║   Yubikey Registration Wizard      ║"
  echo "╚════════════════════════════════════╝"
  echo ""
  echo "This wizard will help you register your Yubikey for U2F authentication."
  echo ""

  # Step 1: Check requirements
  echo "Step 1: Checking requirements..."
  if ! check_pamu2fcfg_installed; then
    echo ""
    echo -e "${YELLOW}Required software is not installed.${NC}"
    echo "Please run the following command to install:"
    echo ""
    echo -e "${BLUE}$(get_install_command)${NC}"
    echo ""
    read -p "Press Enter to exit..."
    return 1
  fi
  echo -e "${GREEN}✓ Requirements met${NC}"
  echo ""

  # Step 2: User selection
  echo "Step 2: User selection"
  echo "Register Yubikey for user: $USER"
  read -p "Use different username? (y/N): " -n 1 -r
  echo

  local target_user="$USER"
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter username: " target_user
  fi
  echo ""

  # Step 3: Register key
  echo "Step 3: Yubikey registration"
  register_yubikey "$target_user"
  local result=$?

  echo ""
  if [[ $result -eq 0 ]]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}    Registration Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Your Yubikey is now registered for U2F authentication."
    echo "You can test it by running: sudo -k && sudo echo 'Success'"
    echo "(after PAM configuration is complete)"
  else
    echo -e "${RED}Registration failed. Please try again.${NC}"
  fi

  echo ""
  read -p "Press Enter to exit..."
  return $result
}

#!/bin/bash

# PAM Configuration Parser and Validator
# Provides functions to safely parse and validate PAM configuration files

# Valid PAM module types
readonly VALID_MODULE_TYPES="auth account password session"

# Valid PAM control flags (simple flags only, complex flags handled separately)
readonly VALID_CONTROL_FLAGS="required requisite sufficient optional include substack"

# Function: Check if line is comment or blank
# Arguments: $1 - line to check
# Returns: 0 if comment/blank, 1 otherwise
is_comment_or_blank() {
  local line="$1"

  # Remove leading/trailing whitespace
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Check if empty or starts with #
  if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
    return 0
  fi

  return 1
}

# Function: Parse a single PAM configuration line
# Arguments: $1 - PAM configuration line
# Outputs: Parsed components in format "key:value"
# Returns: 0 on success, 1 on parse error
parse_pam_line() {
  local line="$1"

  # Skip comments and blank lines
  if is_comment_or_blank "$line"; then
    echo "type:comment"
    return 0
  fi

  # Check for @include directive
  if [[ "$line" =~ ^@include[[:space:]]+(.*) ]]; then
    echo "directive:include"
    echo "target:${BASH_REMATCH[1]}"
    return 0
  fi

  # Remove leading/trailing whitespace and collapse multiple spaces
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' ')

  # Parse PAM line components
  # Format: module-type control-flag module-path [module-arguments]

  # Handle complex control flags with brackets
  if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+(\[[^]]+\])[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
    local module_type="${BASH_REMATCH[1]}"
    local control_flag="${BASH_REMATCH[2]}"
    local module_path="${BASH_REMATCH[3]}"
    local module_args="${BASH_REMATCH[4]}"
  # Handle simple control flags
  elif [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
    local module_type="${BASH_REMATCH[1]}"
    local control_flag="${BASH_REMATCH[2]}"
    local module_path="${BASH_REMATCH[3]}"
    local module_args="${BASH_REMATCH[4]}"
  else
    echo "error:Failed to parse line"
    return 1
  fi

  # Trim module_args
  module_args=$(echo "$module_args" | sed 's/^[[:space:]]*//')

  # Output parsed components
  echo "module_type:$module_type"
  echo "control_flag:$control_flag"
  echo "module_path:$module_path"
  [[ -n "$module_args" ]] && echo "module_args:$module_args"

  return 0
}

# Function: Validate PAM syntax
# Arguments: $1 - PAM configuration line
# Returns: 0 if valid, 1 if invalid
validate_pam_syntax() {
  local line="$1"

  # Skip comments and blank lines
  if is_comment_or_blank "$line"; then
    return 0
  fi

  # Skip @include directives
  if [[ "$line" =~ ^@include ]]; then
    return 0
  fi

  # Parse the line
  local parsed_output
  parsed_output=$(parse_pam_line "$line")

  if [[ "$parsed_output" =~ Error: ]]; then
    echo "$parsed_output"  # Pass through the actual error message
    return 1
  fi

  # Extract components
  local module_type
  module_type=$(echo "$parsed_output" | grep "^module_type:" | cut -d: -f2)
  local control_flag
  control_flag=$(echo "$parsed_output" | grep "^control_flag:" | cut -d: -f2)
  local module_path
  module_path=$(echo "$parsed_output" | grep "^module_path:" | cut -d: -f2)

  # Validate module type
  if [[ ! " $VALID_MODULE_TYPES " == *" $module_type "* ]]; then
    echo "Error: Invalid module type: $module_type"
    return 1
  fi

  # Validate control flag (simple flags or complex with brackets)
  if [[ ! "$control_flag" =~ ^\[.*\]$ ]]; then
    if [[ ! " $VALID_CONTROL_FLAGS " == *" $control_flag "* ]]; then
      echo "Error: Invalid control flag: $control_flag"
      return 1
    fi
  fi

  # Validate module path exists
  if [[ -z "$module_path" ]]; then
    echo "Error: Missing module path"
    return 1
  fi

  return 0
}

# Function: Check if line contains U2F module
# Arguments: $1 - PAM configuration line
# Returns: 0 if U2F module found, 1 otherwise
has_u2f_module() {
  local line="$1"

  if [[ "$line" =~ pam_u2f\.so ]] || [[ "$line" =~ pam_yubico\.so ]]; then
    return 0
  fi

  return 1
}

# Function: Find optimal insertion point for pam_u2f
# Arguments: $1 - PAM file path
# Outputs: Line number for insertion
# Returns: 0 on success
find_insertion_point() {
  local pam_file="$1"
  local line_num=0
  local after_env_line=0
  local before_unix_line=0
  local first_auth_line=0

  while IFS= read -r line; do
    ((line_num++))

    # Look for auth lines (don't skip comments for line counting)
    if [[ "$line" =~ ^auth[[:space:]] ]]; then
      # Track first auth line
      if [[ $first_auth_line -eq 0 ]]; then
        first_auth_line=$line_num
      fi

      # Find pam_env.so - we want to insert after this
      if [[ "$line" =~ pam_env\.so ]]; then
        after_env_line=$line_num
      fi

      # Find first pam_unix.so - we want to insert before this
      if [[ "$line" =~ pam_unix\.so ]] && [[ $before_unix_line -eq 0 ]]; then
        before_unix_line=$line_num
      fi
    fi
  done <"$pam_file"

  # Determine best insertion point
  # Priority: after pam_env.so, before pam_unix.so, or after first auth
  if [[ $after_env_line -gt 0 ]]; then
    # Insert on the next line after pam_env
    echo "$((after_env_line + 1))"
  elif [[ $before_unix_line -gt 0 ]]; then
    # Insert right before pam_unix
    echo "$before_unix_line"
  elif [[ $first_auth_line -gt 0 ]]; then
    # Insert after first auth line
    echo "$((first_auth_line + 1))"
  else
    echo "2" # Default to line 2 if no auth lines found
  fi

  return 0
}

# Function: Parse entire PAM file
# Arguments: $1 - PAM file path
# Outputs: File analysis summary
# Returns: 0 on success, 1 on error
parse_pam_file() {
  local pam_file="$1"

  if [[ ! -f "$pam_file" ]]; then
    echo "error:File not found: $pam_file"
    return 1
  fi

  local total_lines=0
  local auth_lines=0
  local account_lines=0
  local password_lines=0
  local session_lines=0
  local comment_lines=0
  local include_lines=0
  local u2f_found=false

  while IFS= read -r line; do
    ((total_lines++))

    if is_comment_or_blank "$line"; then
      ((comment_lines++))
      continue
    fi

    if [[ "$line" =~ ^@include ]]; then
      ((include_lines++))
      continue
    fi

    if has_u2f_module "$line"; then
      u2f_found=true
    fi

    # Count module types
    case "$line" in
      auth*) ((auth_lines++)) ;;
      account*) ((account_lines++)) ;;
      password*) ((password_lines++)) ;;
      session*) ((session_lines++)) ;;
    esac
  done <"$pam_file"

  # Output analysis
  echo "file:$pam_file"
  echo "total_lines:$total_lines"
  echo "auth_lines:$auth_lines"
  echo "account_lines:$account_lines"
  echo "password_lines:$password_lines"
  echo "session_lines:$session_lines"
  echo "comment_lines:$comment_lines"
  echo "include_lines:$include_lines"
  echo "u2f_module_found:$u2f_found"

  return 0
}

# Function: Validate entire PAM file
# Arguments: $1 - PAM file path
# Returns: 0 if all lines valid, 1 if any errors
validate_pam_file() {
  local pam_file="$1"
  local line_num=0
  local errors=0

  if [[ ! -f "$pam_file" ]]; then
    echo "error:File not found: $pam_file"
    return 1
  fi

  while IFS= read -r line; do
    ((line_num++))

    if ! validate_pam_syntax "$line"; then
      echo "Line $line_num: $line"
      ((errors++))
    fi
  done <"$pam_file"

  if [[ $errors -gt 0 ]]; then
    echo "Total errors: $errors"
    return 1
  fi

  echo "Validation successful: All lines are valid"
  return 0
}

# Function: Analyze PAM configuration structure
# Arguments: $1 - PAM file path
# Outputs: Detailed structure analysis
# Returns: 0 on success
analyze_pam_structure() {
  local pam_file="$1"
  local current_section=""
  # local auth_stack=""  # Reserved for future authentication stack analysis
  local has_sufficient=false
  local has_required=false

  echo "=== PAM Structure Analysis ==="
  echo "File: $pam_file"
  echo ""

  while IFS= read -r line; do
    if is_comment_or_blank "$line"; then
      continue
    fi

    # Parse the line
    local parsed_output
    parsed_output=$(parse_pam_line "$line")

    local module_type
    module_type=$(echo "$parsed_output" | grep "^module_type:" | cut -d: -f2)
    local control_flag
    control_flag=$(echo "$parsed_output" | grep "^control_flag:" | cut -d: -f2)
    local module_path
    module_path=$(echo "$parsed_output" | grep "^module_path:" | cut -d: -f2)

    # Track section changes
    if [[ "$module_type" != "$current_section" ]]; then
      if [[ -n "$current_section" ]]; then
        echo ""
      fi
      current_section="$module_type"
      echo "[$module_type]"
    fi

    # Analyze control flow
    case "$control_flag" in
      required)
        echo "  → $module_path (MUST succeed)"
        has_required=true
        ;;
      requisite)
        echo "  → $module_path (MUST succeed, fail immediately)"
        ;;
      sufficient)
        echo "  → $module_path (success is enough)"
        has_sufficient=true
        ;;
      optional)
        echo "  → $module_path (optional)"
        ;;
      substack | include)
        echo "  ↳ $module_path (include stack)"
        ;;
      *)
        echo "  → $module_path ($control_flag)"
        ;;
    esac

    # Check for U2F modules
    if has_u2f_module "$line"; then
      echo "    [U2F MODULE DETECTED]"
    fi
  done <"$pam_file"

  echo ""
  echo "=== Analysis Summary ==="

  # Provide recommendations
  if [[ "$has_sufficient" == true ]] && [[ "$has_required" == true ]]; then
    echo "✓ Good: Mix of sufficient and required modules allows fallback"
  fi

  # Check if U2F already configured
  local file_analysis
  file_analysis=$(parse_pam_file "$pam_file")
  if [[ "$file_analysis" =~ u2f_module_found:true ]]; then
    echo "⚠ Warning: U2F module already configured"
  else
    echo "✓ Ready: No existing U2F configuration found"
  fi

  # Find insertion point
  local insert_line
  insert_line=$(find_insertion_point "$pam_file")
  echo "→ Recommended insertion point: Line $insert_line"

  return 0
}

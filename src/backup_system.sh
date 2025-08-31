#!/bin/bash

# PAM Configuration Backup System
# Provides safe backup and restore functionality for PAM configurations

# Default locations
readonly DEFAULT_PAM_DIR="/etc/pam.d"
readonly DEFAULT_BACKUP_BASE="/etc"
readonly DEFAULT_LOG_FILE="/var/log/yubikey-pam-installer.log"

# Minimum required disk space in KB (10MB)
readonly MIN_DISK_SPACE_KB=10240

# Function: Create timestamped backup directory
# Arguments: $1 - Base backup directory (optional)
# Outputs: Path to created backup directory
# Returns: 0 on success, 1 on error
create_backup_directory() {
  local base_dir="${1:-$DEFAULT_BACKUP_BASE}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_dir="$base_dir/pam.d.backup-$timestamp"

  # Create the backup directory
  if mkdir -p "$backup_dir"; then
    echo "$backup_dir"
    return 0
  else
    echo "Error: Failed to create backup directory: $backup_dir" >&2
    return 1
  fi
}

# Function: Check available disk space
# Arguments: $1 - Directory to check, $2 - Required space in KB
# Returns: 0 if sufficient space, 1 if insufficient
check_disk_space() {
  local check_dir="$1"
  local required_kb="${2:-$MIN_DISK_SPACE_KB}"

  # Get available space in KB
  local available_kb
  available_kb=$(df -k "$check_dir" 2>/dev/null | awk 'NR==2 {print $4}')

  if [[ -z "$available_kb" ]]; then
    echo "Error: Unable to determine available disk space" >&2
    return 1
  fi

  if [[ $available_kb -lt $required_kb ]]; then
    echo "Error: Insufficient disk space. Required: ${required_kb}KB, Available: ${available_kb}KB" >&2
    return 1
  fi

  return 0
}

# Function: Backup PAM configuration
# Arguments: $1 - Source PAM directory, $2 - Destination backup directory
# Returns: 0 on success, 1 on error
backup_pam_config() {
  local source_dir="${1:-$DEFAULT_PAM_DIR}"
  local backup_dir="$2"

  # Validate source directory
  if [[ ! -d "$source_dir" ]]; then
    echo "Error: Source directory not found: $source_dir" >&2
    return 1
  fi

  # Validate backup directory
  if [[ -z "$backup_dir" ]]; then
    echo "Error: Backup directory not specified" >&2
    return 1
  fi

  # Ensure backup directory exists
  if [[ ! -d "$backup_dir" ]]; then
    mkdir -p "$backup_dir" || {
      echo "Error: Cannot create backup directory: $backup_dir" >&2
      return 1
    }
  fi

  # Check if backup directory is writable
  if [[ ! -w "$backup_dir" ]]; then
    echo "Error: Backup directory is not writable: $backup_dir" >&2
    return 1
  fi

  # Copy files with permissions preserved
  # Using cp -a to preserve all attributes
  if cp -a "$source_dir"/* "$backup_dir"/ 2>/dev/null; then
    echo "Backup created successfully at: $backup_dir"
    return 0
  else
    echo "Error: Failed to copy PAM configuration files" >&2
    # Attempt cleanup of partial backup
    rm -rf "$backup_dir"
    return 1
  fi
}

# Function: Verify backup integrity
# Arguments: $1 - Original directory, $2 - Backup directory
# Returns: 0 if identical, 1 if differences found
verify_backup() {
  local original_dir="$1"
  local backup_dir="$2"

  # Check both directories exist
  if [[ ! -d "$original_dir" ]] || [[ ! -d "$backup_dir" ]]; then
    echo "Error: Directory not found for verification" >&2
    return 1
  fi

  # Use diff to compare directories
  if diff -rq "$original_dir" "$backup_dir" >/dev/null 2>&1; then
    echo "Backup verified successfully"
    return 0
  else
    echo "Warning: Backup verification failed - differences found" >&2
    diff -rq "$original_dir" "$backup_dir" 2>/dev/null | head -10
    return 1
  fi
}

# Function: Log action to file
# Arguments: $1 - Action type, $2 - Message, $3 - Log file (optional)
# Returns: 0 on success
log_action() {
  local action_type="$1"
  local message="$2"
  local log_file="${3:-$DEFAULT_LOG_FILE}"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Create log directory if it doesn't exist
  local log_dir
  log_dir=$(dirname "$log_file")
  [[ -d "$log_dir" ]] || mkdir -p "$log_dir"

  # Append to log file
  echo "[$timestamp] [$action_type] $message" >>"$log_file"

  return 0
}

# Function: Restore from backup
# Arguments: $1 - Backup directory, $2 - Target directory
# Returns: 0 on success, 1 on error
restore_from_backup() {
  local backup_dir="$1"
  local target_dir="${2:-$DEFAULT_PAM_DIR}"

  # Validate backup directory
  if [[ ! -d "$backup_dir" ]]; then
    echo "Error: Backup directory not found: $backup_dir" >&2
    return 1
  fi

  # Check if backup contains PAM files
  if ! ls "$backup_dir"/* >/dev/null 2>&1; then
    echo "Error: Backup directory is empty: $backup_dir" >&2
    return 1
  fi

  # Ensure target directory exists
  if [[ ! -d "$target_dir" ]]; then
    mkdir -p "$target_dir" || {
      echo "Error: Cannot create target directory: $target_dir" >&2
      return 1
    }
  fi

  # Restore files with permissions
  if cp -a "$backup_dir"/* "$target_dir"/ 2>/dev/null; then
    echo "Configuration restored successfully from: $backup_dir"
    return 0
  else
    echo "Error: Failed to restore configuration" >&2
    return 1
  fi
}

# Function: List available backups
# Arguments: $1 - Backup base directory
# Outputs: List of backup directories sorted by date
# Returns: 0 on success
list_backups() {
  local base_dir="${1:-$DEFAULT_BACKUP_BASE}"

  if [[ ! -d "$base_dir" ]]; then
    echo "No backups found in: $base_dir" >&2
    return 1
  fi

  # Find and list backup directories
  local backups
  backups=$(find "$base_dir" -maxdepth 1 -type d -name "pam.d.backup-*" 2>/dev/null | sort)

  if [[ -z "$backups" ]]; then
    echo "No backups found"
    return 1
  fi

  echo "Available backups:"
  for backup in $backups; do
    local backup_name
    backup_name=$(basename "$backup")
    # Extract date from backup name (for potential future use)
    # local backup_date=${backup_name#pam.d.backup-}

    # Check if metadata exists
    if [[ -f "$backup/.backup_metadata" ]]; then
      local description
      description=$(grep "^description=" "$backup/.backup_metadata" 2>/dev/null | cut -d= -f2)
      echo "  $backup_name - $description"
    else
      echo "  $backup_name"
    fi
  done

  return 0
}

# Function: Get latest backup
# Arguments: $1 - Backup base directory
# Outputs: Path to latest backup
# Returns: 0 if found, 1 if not
get_latest_backup() {
  local base_dir="${1:-$DEFAULT_BACKUP_BASE}"

  local latest
  latest=$(find "$base_dir" -maxdepth 1 -type d -name "pam.d.backup-*" 2>/dev/null | sort | tail -1)

  if [[ -n "$latest" ]]; then
    echo "$latest"
    return 0
  else
    echo "No backups found" >&2
    return 1
  fi
}

# Function: Save backup metadata
# Arguments: $1 - Backup directory, $2 - Description
# Returns: 0 on success
save_backup_metadata() {
  local backup_dir="$1"
  local description="$2"
  local metadata_file="$backup_dir/.backup_metadata"

  if [[ ! -d "$backup_dir" ]]; then
    echo "Error: Backup directory not found: $backup_dir" >&2
    return 1
  fi

  # Write metadata
  {
    echo "timestamp=$(date '+%Y-%m-%d %H:%M:%S')"
    echo "description=$description"
    echo "hostname=$(hostname)"
    echo "user=$USER"
    echo "pam_files_count=$(find "$backup_dir" -type f | wc -l)"
  } >"$metadata_file"

  return 0
}

# Function: Read backup metadata
# Arguments: $1 - Backup directory
# Outputs: Metadata contents
# Returns: 0 if found, 1 if not
read_backup_metadata() {
  local backup_dir="$1"
  local metadata_file="$backup_dir/.backup_metadata"

  if [[ ! -f "$metadata_file" ]]; then
    echo "No metadata found for backup" >&2
    return 1
  fi

  cat "$metadata_file"
  return 0
}

# Function: Perform full backup with all safety checks
# Arguments: $1 - Description (optional)
# Returns: 0 on success, 1 on error
perform_safe_backup() {
  local description="${1:-Manual backup}"

  echo "Starting PAM configuration backup..."

  # Check disk space
  if ! check_disk_space "$DEFAULT_BACKUP_BASE" $MIN_DISK_SPACE_KB; then
    return 1
  fi

  # Create backup directory
  local backup_dir
  backup_dir=$(create_backup_directory "$DEFAULT_BACKUP_BASE")

  if [[ -z "$backup_dir" ]]; then
    echo "Error: Failed to create backup directory" >&2
    return 1
  fi

  # Perform backup
  if ! backup_pam_config "$DEFAULT_PAM_DIR" "$backup_dir"; then
    echo "Error: Backup failed" >&2
    return 1
  fi

  # Verify backup
  if ! verify_backup "$DEFAULT_PAM_DIR" "$backup_dir"; then
    echo "Warning: Backup verification failed, but backup was created" >&2
  fi

  # Save metadata
  save_backup_metadata "$backup_dir" "$description"

  # Log the action
  log_action "BACKUP" "Created backup at $backup_dir - $description"

  echo "Backup completed successfully: $backup_dir"
  return 0
}

# Function: Perform safe restore
# Arguments: $1 - Backup directory (optional, uses latest if not specified)
# Returns: 0 on success, 1 on error
perform_safe_restore() {
  local backup_dir="${1}"

  # If no backup specified, use latest
  if [[ -z "$backup_dir" ]]; then
    backup_dir=$(get_latest_backup "$DEFAULT_BACKUP_BASE")
    if [[ -z "$backup_dir" ]]; then
      echo "Error: No backups found to restore" >&2
      return 1
    fi
    echo "Using latest backup: $backup_dir"
  fi

  # Validate backup exists
  if [[ ! -d "$backup_dir" ]]; then
    echo "Error: Backup directory not found: $backup_dir" >&2
    return 1
  fi

  # Create safety backup before restore
  echo "Creating safety backup before restore..."
  local safety_backup
  safety_backup=$(create_backup_directory "$DEFAULT_BACKUP_BASE")

  if backup_pam_config "$DEFAULT_PAM_DIR" "$safety_backup"; then
    save_backup_metadata "$safety_backup" "Pre-restore safety backup"
    log_action "BACKUP" "Created safety backup before restore: $safety_backup"
  else
    echo "Warning: Could not create safety backup" >&2
    read -p "Continue with restore anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      return 1
    fi
  fi

  # Perform restore
  echo "Restoring from: $backup_dir"
  if restore_from_backup "$backup_dir" "$DEFAULT_PAM_DIR"; then
    log_action "RESTORE" "Restored configuration from $backup_dir"
    echo "Restore completed successfully"
    return 0
  else
    echo "Error: Restore failed" >&2
    log_action "ERROR" "Failed to restore from $backup_dir"
    return 1
  fi
}

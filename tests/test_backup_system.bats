#!/usr/bin/env bats

# Test suite for PAM Configuration Backup System

setup() {
  # Source the backup functions
  source "${BATS_TEST_DIRNAME}/../src/backup_system.sh"
  
  # Create temp directory for testing
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
  export TEST_PAM_DIR="$TEST_DIR/pam.d"
  export TEST_BACKUP_DIR="$TEST_DIR/backups"
  export TEST_LOG_FILE="$TEST_DIR/yubikey-pam-installer.log"
  
  # Create mock PAM directory with files
  mkdir -p "$TEST_PAM_DIR"
  echo "auth required pam_unix.so" > "$TEST_PAM_DIR/sudo"
  echo "auth required pam_unix.so" > "$TEST_PAM_DIR/su"
  echo "@include common-auth" > "$TEST_PAM_DIR/login"
  
  # Set specific permissions for testing
  chmod 644 "$TEST_PAM_DIR/sudo"
  chmod 644 "$TEST_PAM_DIR/su"
  chmod 644 "$TEST_PAM_DIR/login"
}

teardown() {
  # Clean up test directory
  rm -rf "$TEST_DIR"
}

# Test: Create timestamped backup directory
@test "create timestamped backup directory" {
  run create_backup_directory "$TEST_BACKUP_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ pam\.d\.backup-[0-9]{8}-[0-9]{6} ]]
}

@test "backup directory has correct timestamp format" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  [[ "$backup_dir" =~ [0-9]{8}-[0-9]{6}$ ]]
}

# Test: Backup PAM configuration
@test "backup entire PAM directory" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  run backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  [ "$status" -eq 0 ]
  [ -f "$backup_dir/sudo" ]
  [ -f "$backup_dir/su" ]
  [ -f "$backup_dir/login" ]
}

@test "preserve file permissions during backup" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  chmod 600 "$TEST_PAM_DIR/sudo"
  
  backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  
  original_perms=$(stat -c %a "$TEST_PAM_DIR/sudo")
  backup_perms=$(stat -c %a "$backup_dir/sudo")
  [ "$original_perms" = "$backup_perms" ]
}

@test "preserve file ownership during backup" {
  skip "Requires root to test ownership preservation"
  # This test would require root privileges to change ownership
}

# Test: Verify backup integrity
@test "verify backup with diff" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  
  run verify_backup "$TEST_PAM_DIR" "$backup_dir"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Backup verified successfully" ]]
}

@test "detect backup differences" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  
  # Modify original after backup
  echo "auth required pam_deny.so" >> "$TEST_PAM_DIR/sudo"
  
  run verify_backup "$TEST_PAM_DIR" "$backup_dir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "differences found" ]]
}

# Test: Logging functionality
@test "log backup creation" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  run log_action "BACKUP" "Created backup at $backup_dir" "$TEST_LOG_FILE"
  [ "$status" -eq 0 ]
  [ -f "$TEST_LOG_FILE" ]
  grep -q "BACKUP" "$TEST_LOG_FILE"
}

@test "log with timestamp" {
  run log_action "TEST" "Test message" "$TEST_LOG_FILE"
  [ "$status" -eq 0 ]
  grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" "$TEST_LOG_FILE"
}

@test "append to existing log" {
  log_action "FIRST" "First message" "$TEST_LOG_FILE"
  log_action "SECOND" "Second message" "$TEST_LOG_FILE"
  
  line_count=$(wc -l < "$TEST_LOG_FILE")
  [ "$line_count" -eq 2 ]
}

# Test: Restore functionality
@test "restore from backup" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  
  # Modify original
  echo "modified" > "$TEST_PAM_DIR/sudo"
  
  run restore_from_backup "$backup_dir" "$TEST_PAM_DIR"
  [ "$status" -eq 0 ]
  
  # Check file was restored
  grep -q "auth required pam_unix.so" "$TEST_PAM_DIR/sudo"
}

@test "restore preserves permissions" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  chmod 600 "$TEST_PAM_DIR/sudo"
  backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  
  # Change permissions and restore
  chmod 777 "$TEST_PAM_DIR/sudo"
  restore_from_backup "$backup_dir" "$TEST_PAM_DIR"
  
  restored_perms=$(stat -c %a "$TEST_PAM_DIR/sudo")
  [ "$restored_perms" = "600" ]
}

@test "validate backup before restore" {
  run restore_from_backup "/nonexistent/backup" "$TEST_PAM_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Backup directory not found" ]]
}

# Test: List available backups
@test "list available backups" {
  # Create multiple backups
  backup1=$(create_backup_directory "$TEST_BACKUP_DIR")
  sleep 1
  backup2=$(create_backup_directory "$TEST_BACKUP_DIR")
  
  run list_backups "$TEST_BACKUP_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ $(basename "$backup1") ]]
  [[ "$output" =~ $(basename "$backup2") ]]
}

@test "list backups sorted by date" {
  backup1=$(create_backup_directory "$TEST_BACKUP_DIR")
  sleep 1
  backup2=$(create_backup_directory "$TEST_BACKUP_DIR")
  
  backups=$(list_backups "$TEST_BACKUP_DIR" | tail -2)
  first_backup=$(echo "$backups" | head -1)
  second_backup=$(echo "$backups" | tail -1)
  
  [[ "$second_backup" > "$first_backup" ]]
}

# Test: Get latest backup
@test "get latest backup" {
  backup1=$(create_backup_directory "$TEST_BACKUP_DIR")
  sleep 1
  backup2=$(create_backup_directory "$TEST_BACKUP_DIR")
  
  run get_latest_backup "$TEST_BACKUP_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ $(basename "$backup2") ]]
}

# Test: Backup with safety checks
@test "require sufficient disk space" {
  # Skip in CI/Docker where df might behave differently
  if [ -n "$CI" ] || [ -f /.dockerenv ]; then
    skip "Skipping disk space test in CI/Docker environment"
  fi
  
  run check_disk_space "$TEST_BACKUP_DIR" 1
  [ "$status" -eq 0 ]
}

@test "detect insufficient disk space" {
  # Skip in CI/Docker where df might behave differently
  if [ -n "$CI" ] || [ -f /.dockerenv ]; then
    skip "Skipping disk space test in CI/Docker environment"
  fi
  
  # Request 1TB of space (should fail on most systems)
  run check_disk_space "$TEST_BACKUP_DIR" 1000000000
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Insufficient disk space" ]]
}

# Test: Atomic backup operations
@test "atomic backup with rollback on error" {
  # Skip in CI/Docker where permissions might work differently
  if [ -n "$CI" ] || [ -f /.dockerenv ]; then
    skip "Skipping atomic backup test in CI/Docker environment"
  fi
  
  # Simulate error during backup
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  
  # Make destination read-only to force error
  chmod 555 "$backup_dir"
  
  run backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  [ "$status" -eq 1 ]
  
  # Cleanup should have removed partial backup
  chmod 755 "$backup_dir"
}

# Test: Backup metadata
@test "save backup metadata" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  backup_pam_config "$TEST_PAM_DIR" "$backup_dir"
  
  run save_backup_metadata "$backup_dir" "Pre-installation backup"
  [ "$status" -eq 0 ]
  [ -f "$backup_dir/.backup_metadata" ]
  grep -q "Pre-installation backup" "$backup_dir/.backup_metadata"
}

@test "read backup metadata" {
  backup_dir=$(create_backup_directory "$TEST_BACKUP_DIR")
  save_backup_metadata "$backup_dir" "Test backup"
  
  run read_backup_metadata "$backup_dir"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test backup" ]]
}
#!/bin/bash

# Demo script for PAM backup system functionality

source src/backup_system.sh

# Create demo environment
DEMO_DIR="/tmp/yubikey_pam_demo"
DEMO_PAM_DIR="$DEMO_DIR/pam.d"
DEMO_BACKUP_BASE="$DEMO_DIR/backups"

# Cleanup function
cleanup() {
  echo ""
  echo "Cleaning up demo files..."
  rm -rf "$DEMO_DIR"
}
trap cleanup EXIT

# Setup demo PAM directory
setup_demo() {
  mkdir -p "$DEMO_PAM_DIR"

  # Create realistic PAM files
  cat >"$DEMO_PAM_DIR/sudo" <<'EOF'
#%PAM-1.0
auth       required   pam_env.so
auth       required   pam_unix.so nullok_secure
account    required   pam_unix.so
password   required   pam_unix.so obscure sha512
session    required   pam_unix.so
session    optional   pam_umask.so
EOF

  cat >"$DEMO_PAM_DIR/su" <<'EOF'
#%PAM-1.0
auth       sufficient pam_rootok.so
auth       required   pam_unix.so
account    required   pam_unix.so
session    required   pam_unix.so
EOF

  cat >"$DEMO_PAM_DIR/login" <<'EOF'
#%PAM-1.0
auth       required   pam_securetty.so
auth       required   pam_unix.so nullok
account    required   pam_unix.so
password   required   pam_unix.so sha512
session    required   pam_unix.so
EOF

  # Set realistic permissions
  chmod 644 "$DEMO_PAM_DIR"/*
}

echo "==================================="
echo "PAM Backup System Demonstration"
echo "==================================="
echo ""

echo "Setting up demo environment..."
setup_demo
echo "✓ Created demo PAM directory at: $DEMO_PAM_DIR"
echo ""

echo "1. Creating initial backup"
echo "-----------------------------------"
backup1=$(create_backup_directory "$DEMO_BACKUP_BASE")
backup_pam_config "$DEMO_PAM_DIR" "$backup1"
save_backup_metadata "$backup1" "Initial PAM configuration"
echo ""

echo "2. Simulating PAM modification"
echo "-----------------------------------"
echo "Adding pam_u2f.so to sudo configuration..."
sed -i '2a auth       sufficient pam_u2f.so authfile=/etc/u2f_keys' "$DEMO_PAM_DIR/sudo"
echo "✓ Modified $DEMO_PAM_DIR/sudo"
echo ""

echo "3. Creating post-modification backup"
echo "-----------------------------------"
sleep 1 # Ensure different timestamp
backup2=$(create_backup_directory "$DEMO_BACKUP_BASE")
backup_pam_config "$DEMO_PAM_DIR" "$backup2"
save_backup_metadata "$backup2" "After adding U2F authentication"
echo ""

echo "4. Listing available backups"
echo "-----------------------------------"
list_backups "$DEMO_BACKUP_BASE"
echo ""

echo "5. Showing backup metadata"
echo "-----------------------------------"
echo "Latest backup metadata:"
latest=$(get_latest_backup "$DEMO_BACKUP_BASE")
read_backup_metadata "$latest"
echo ""

echo "6. Verifying current configuration against original backup"
echo "-----------------------------------"
echo "Checking for differences..."
if verify_backup "$DEMO_PAM_DIR" "$backup1" 2>/dev/null; then
  echo "✓ No changes detected"
else
  echo "✗ Changes detected (expected - we modified sudo)"
  echo ""
  echo "Differences:"
  diff -u "$backup1/sudo" "$DEMO_PAM_DIR/sudo" | head -10
fi
echo ""

echo "7. Demonstrating restore capability"
echo "-----------------------------------"
echo "Current sudo config (modified):"
grep pam_u2f "$DEMO_PAM_DIR/sudo" || echo "  (no pam_u2f found)"
echo ""

echo "Restoring from original backup..."
restore_from_backup "$backup1" "$DEMO_PAM_DIR"
echo ""

echo "Sudo config after restore:"
grep pam_u2f "$DEMO_PAM_DIR/sudo" 2>/dev/null || echo "  (no pam_u2f found - successfully restored to original)"
echo ""

echo "8. Disk space check"
echo "-----------------------------------"
if check_disk_space "$DEMO_BACKUP_BASE" 1024; then
  echo "✓ Sufficient disk space available"
else
  echo "✗ Insufficient disk space"
fi
echo ""

echo "9. Log file demonstration"
echo "-----------------------------------"
LOG_FILE="$DEMO_DIR/install.log"
log_action "DEMO" "Demonstration started" "$LOG_FILE"
log_action "BACKUP" "Created initial backup" "$LOG_FILE"
log_action "MODIFY" "Added U2F authentication" "$LOG_FILE"
log_action "RESTORE" "Restored original configuration" "$LOG_FILE"

echo "Log contents:"
cat "$LOG_FILE"
echo ""

echo "==================================="
echo "Demo completed successfully!"
echo ""
echo "Key Features Demonstrated:"
echo "  ✓ Timestamped backup creation"
echo "  ✓ Permission preservation"
echo "  ✓ Backup verification with diff"
echo "  ✓ Metadata storage and retrieval"
echo "  ✓ Safe restore functionality"
echo "  ✓ Comprehensive logging"
echo "  ✓ Disk space checking"
echo "====================================="

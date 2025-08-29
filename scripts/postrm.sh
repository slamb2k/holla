#!/bin/bash
# Post-removal script for Yubikey PAM Installer

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Yubikey PAM Installer - Post-removal Cleanup"

# Remove symlinks
echo "Removing symlinks..."
rm -f /usr/local/bin/yubikey-register
rm -f /usr/local/bin/yubikey-backup

# Handle purge vs remove
if [ "$1" = "purge" ]; then
  echo "Purging configuration and logs..."
  
  # Remove logs
  rm -rf /var/log/yubikey-pam
  
  # Remove configuration directory (but preserve backups)
  if [ -d /etc/yubikey-pam ]; then
    # Save backup directory if it exists
    if [ -d /etc/yubikey-pam/backup ]; then
      echo -e "${YELLOW}Preserving /etc/yubikey-pam/backup for safety${NC}"
      mv /etc/yubikey-pam/backup /tmp/yubikey-pam-backup-$(date +%Y%m%d-%H%M%S)
      echo "Backups moved to /tmp/"
    fi
    rm -rf /etc/yubikey-pam
  fi
else
  echo "Configuration and logs preserved (use purge to remove)"
fi

# Final check for PAM configuration
if grep -q "pam_u2f.so" /etc/pam.d/* 2>/dev/null; then
  echo ""
  echo -e "${YELLOW}⚠ WARNING: Yubikey PAM configuration still active!${NC}"
  echo ""
  echo "To restore original PAM configuration:"
  if ls -d /etc/pam.d.backup-* 2>/dev/null | head -1 >/dev/null; then
    latest_backup=$(ls -dt /etc/pam.d.backup-* 2>/dev/null | head -1)
    echo "  sudo cp -r $latest_backup/* /etc/pam.d/"
  else
    echo "  Manually edit files in /etc/pam.d/ to remove pam_u2f.so lines"
  fi
  echo ""
fi

echo -e "${GREEN}✓ Yubikey PAM Installer removed${NC}"

exit 0
#!/bin/bash
# Pre-removal script for Yubikey PAM Installer

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Yubikey PAM Installer - Pre-removal Check"

# Check if PAM is configured with Yubikey
if grep -q "pam_u2f.so" /etc/pam.d/* 2>/dev/null; then
  echo -e "${YELLOW}⚠ WARNING: Yubikey PAM configuration detected${NC}"
  echo ""
  echo "Found Yubikey configuration in the following files:"
  grep -l "pam_u2f.so" /etc/pam.d/* 2>/dev/null | sed 's/^/  - /'
  echo ""
  echo -e "${RED}IMPORTANT:${NC} Removing this package will NOT automatically"
  echo "remove PAM configuration. This could lock you out of your system!"
  echo ""
  echo "To safely remove Yubikey configuration first, run:"
  echo "  sudo yubikey-pam-uninstall"
  echo ""
  
  # In non-interactive mode, continue (for automated systems)
  if [ ! -t 0 ]; then
    echo "Non-interactive mode detected, continuing..."
  else
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Removal cancelled for safety"
      exit 1
    fi
  fi
fi

# Check for existing backups
if [ -d /etc/pam.d.backup-* ] 2>/dev/null; then
  echo -e "${YELLOW}Note: PAM backups found:${NC}"
  ls -d /etc/pam.d.backup-* 2>/dev/null | sed 's/^/  - /'
  echo "These backups will be preserved"
fi

echo "Proceeding with package removal..."

exit 0
#!/bin/bash
# Post-installation script for Yubikey PAM Installer

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Yubikey PAM Installer - Post Installation${NC}"

# Create necessary directories
echo "Creating directories..."
mkdir -p /var/log/yubikey-pam
mkdir -p /etc/yubikey-pam/backup
chmod 700 /etc/yubikey-pam/backup

# Create symlinks for convenience (if not exists)
if [ ! -L /usr/local/bin/yubikey-register ]; then
  ln -sf /usr/share/yubikey-pam-installer/src/u2f_registration.sh /usr/local/bin/yubikey-register
fi

if [ ! -L /usr/local/bin/yubikey-backup ]; then
  ln -sf /usr/share/yubikey-pam-installer/src/backup_system.sh /usr/local/bin/yubikey-backup
fi

# Check for required dependencies
echo "Checking dependencies..."
if ! command -v pamu2fcfg >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ Warning: pamu2fcfg not found${NC}"
  echo "Please install the required package:"
  if command -v apt-get >/dev/null 2>&1; then
    echo "  sudo apt-get install libpam-u2f pamu2fcfg"
  elif command -v dnf >/dev/null 2>&1; then
    echo "  sudo dnf install pam-u2f pamu2fcfg"
  elif command -v pacman >/dev/null 2>&1; then
    echo "  sudo pacman -S pam-u2f"
  fi
fi

# Check for udev rules
if [ ! -f /etc/udev/rules.d/70-u2f.rules ]; then
  echo -e "${YELLOW}⚠ Yubikey udev rules not found${NC}"
  echo "You may need to install udev rules for Yubikey detection:"
  echo "  sudo wget -O /etc/udev/rules.d/70-u2f.rules \\"
  echo "    https://raw.githubusercontent.com/Yubico/libu2f-host/master/70-u2f.rules"
  echo "  sudo udevadm control --reload-rules"
fi

echo -e "${GREEN}✓ Yubikey PAM Installer successfully installed!${NC}"
echo ""
echo "Quick Start:"
echo "  1. Register your Yubikey:     yubikey-register"
echo "  2. Configure PAM:              yubikey-pam-install"
echo "  3. Test authentication:        sudo -k && sudo echo 'Success!'"
echo ""
echo "Documentation: /usr/share/yubikey-pam-installer/docs/"
echo ""

exit 0

# Installation Guide

This guide covers the installation of the Yubikey PAM Installer on Linux systems.

## System Requirements

### Hardware Requirements

- **Yubikey**: Any Yubikey with U2F support (Yubikey 4, 5, or newer)
- **USB Port**: Available USB-A or USB-C port depending on your Yubikey model

### Software Requirements

- **Operating System**: Linux (Ubuntu 18.04+, Debian 10+, Fedora 32+, Arch, openSUSE)
- **Bash**: Version 5.0 or higher
- **PAM**: Version 1.3.0 or higher
- **Root Access**: Required for PAM configuration modifications

### Required Packages

The following packages must be installed before using the tool:

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install libpam-u2f pamu2fcfg
```

#### Fedora/RHEL

```bash
sudo dnf install pam-u2f pamu2fcfg
```

#### Arch Linux

```bash
sudo pacman -S pam-u2f
```

#### openSUSE

```bash
sudo zypper install pam_u2f
```

## Installation Methods

### Method 1: Quick Install (Recommended)

```bash
# Clone the repository
git clone https://github.com/[org]/yubikey-pam-installer.git
cd yubikey-pam-installer

# Run the installer
sudo ./install.sh
```

### Method 2: Manual Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/[org]/yubikey-pam-installer.git
   cd yubikey-pam-installer
   ```

2. **Make scripts executable**:

   ```bash
   chmod +x src/*.sh
   chmod +x *.sh
   ```

3. **Verify dependencies**:

   ```bash
   ./check-dependencies.sh
   ```

4. **Run installation**:

   ```bash
   sudo ./install.sh
   ```

### Method 3: System Package Installation

For production environments, install via system package:

#### Build Package

```bash
make package
```

#### Install Package

**Debian/Ubuntu**:

```bash
sudo dpkg -i yubikey-pam-installer_*.deb
```

**Fedora/RHEL**:

```bash
sudo rpm -i yubikey-pam-installer-*.rpm
```

**Arch**:

```bash
sudo pacman -U yubikey-pam-installer-*.pkg.tar.xz
```

## Post-Installation Steps

### 1. Register Your Yubikey

After installation, register your Yubikey:

```bash
yubikey-pam-register
```

Or use the interactive wizard:

```bash
yubikey-pam-wizard
```

### 2. Verify Installation

Test the installation with:

```bash
# Test sudo authentication
sudo -k
sudo echo "Authentication successful"

# Check PAM configuration
yubikey-pam-status
```

### 3. Configure Backup Keys

It's recommended to register multiple Yubikeys as backup:

```bash
# Register additional key
yubikey-pam-register --add
```

## Troubleshooting Installation

### Common Issues

#### pamu2fcfg not found

```bash
# Install required packages
sudo apt-get install libpam-u2f pamu2fcfg  # Debian/Ubuntu
sudo dnf install pam-u2f pamu2fcfg         # Fedora
```

#### Permission denied accessing Yubikey

```bash
# Add udev rules for Yubikey
sudo wget -O /etc/udev/rules.d/70-u2f.rules \
  https://raw.githubusercontent.com/Yubico/libu2f-host/master/70-u2f.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

#### PAM configuration backup

Before installation, the tool automatically creates backups:

```bash
# Backups are stored in:
/etc/pam.d.backup-YYYYMMDD-HHMMSS/

# Manual backup (if needed):
sudo cp -r /etc/pam.d /etc/pam.d.backup-manual
```

## Uninstallation

To remove the Yubikey PAM configuration:

```bash
# Restore original PAM configuration
sudo ./uninstall.sh

# Or manually restore from backup
sudo rm -rf /etc/pam.d
sudo cp -r /etc/pam.d.backup-* /etc/pam.d
```

## Security Considerations

⚠️ **WARNING**: Incorrect PAM configuration can lock you out of your system.

### Before Installation

1. Keep a root terminal open: `sudo -s`
2. Test in a VM first if possible
3. Ensure you have physical access to the machine
4. Know your system's recovery procedures

### Recovery Options

If locked out:

1. Boot to recovery mode
2. Mount root filesystem
3. Restore PAM backup: `cp -r /etc/pam.d.backup-* /etc/pam.d`

## Next Steps

- [Quick Start Guide](./quick-start.md) - Get started using your Yubikey
- [Prerequisites](./prerequisites.md) - Detailed prerequisite information
- [Security Model](../architecture/security-model.md) - Understand the security implications

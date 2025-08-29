# Prerequisites

Detailed requirements and preparation steps before installing Yubikey PAM Installer.

## Hardware Requirements

### Yubikey Compatibility

#### Supported Models
- ✅ **Yubikey 5 Series** (5, 5C, 5Ci, 5 NFC, 5C NFC, 5 Nano)
- ✅ **Yubikey 4 Series** (4, 4C, 4 Nano)
- ✅ **Yubikey Security Key Series**
- ✅ **Yubikey FIPS Series** (4 FIPS, 5 FIPS)

#### Required Features
- **U2F Support**: All listed models support U2F
- **Touch Sensor**: Required for authentication confirmation
- **LED Indicator**: Visual feedback during operations

### System Hardware
- **USB Port**: USB-A or USB-C depending on Yubikey model
- **Multiple Ports**: Recommended for backup key registration

## Software Requirements

### Operating System Support

| Distribution | Minimum Version | Tested Versions |
|-------------|-----------------|-----------------|
| Ubuntu | 18.04 LTS | 18.04, 20.04, 22.04, 24.04 |
| Debian | 10 (Buster) | 10, 11, 12 |
| Fedora | 32 | 32-39 |
| RHEL/CentOS | 8 | 8, 9 |
| Arch Linux | Rolling | Current |
| openSUSE | Leap 15.2 | Leap 15.2+ |

### Core Dependencies

#### Required Packages

```bash
# Check Bash version (must be 5.0+)
bash --version

# Check PAM version (must be 1.3.0+)
apt list --installed | grep libpam  # Debian/Ubuntu
rpm -qa | grep pam                  # Fedora/RHEL

# Check for systemd (optional but recommended)
systemctl --version
```

#### Package Installation by Distribution

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install -y \
  libpam-u2f \
  pamu2fcfg \
  libpam-modules \
  libpam-runtime
```

**Fedora/RHEL/CentOS**:
```bash
sudo dnf install -y \
  pam-u2f \
  pamu2fcfg \
  pam \
  pam-devel
```

**Arch Linux**:
```bash
sudo pacman -Sy \
  pam-u2f \
  pam
```

**openSUSE**:
```bash
sudo zypper install -y \
  pam_u2f \
  pam \
  pam-devel
```

### Development Tools (Optional)

For testing and development:

```bash
# Testing framework
sudo apt-get install bats  # Debian/Ubuntu
sudo dnf install bats       # Fedora

# Code quality tools
sudo apt-get install shellcheck shfmt

# Package building
sudo gem install fpm  # Requires Ruby
```

## Access Requirements

### User Permissions

#### Required Access
- **sudo/root**: Required for PAM configuration
- **USB Device Access**: User must be in `plugdev` group

#### Setting Up Permissions
```bash
# Add user to plugdev group (for USB access)
sudo usermod -a -G plugdev $USER

# Logout and login for group changes to take effect
```

### Udev Rules

For proper Yubikey detection:

```bash
# Download official udev rules
sudo wget -O /etc/udev/rules.d/70-u2f.rules \
  https://raw.githubusercontent.com/Yubico/libu2f-host/master/70-u2f.rules

# Reload udev
sudo udevadm control --reload-rules
sudo udevadm trigger

# Verify Yubikey detection
lsusb | grep Yubico
```

## Backup and Recovery Preparation

### Before Installation

#### 1. System Backup
```bash
# Backup critical system files
sudo cp -r /etc/pam.d /etc/pam.d.backup-$(date +%Y%m%d)
sudo cp /etc/sudoers /etc/sudoers.backup-$(date +%Y%m%d)
```

#### 2. Emergency Access
```bash
# Keep a root shell open during installation
sudo -s
# Leave this terminal open!
```

#### 3. Recovery Media
- Have a Linux Live USB ready
- Know how to boot to recovery mode
- Document your partition layout: `lsblk`

### Backup Keys

**IMPORTANT**: Always register at least 2 Yubikeys

#### Why Multiple Keys?
- Primary key loss/damage protection
- Travel backup (leave one in safe location)
- Emergency access guarantee

#### Registering Backup Keys
```bash
# Register first key
./src/u2f_registration.sh

# Register backup key
./src/u2f_registration.sh
# Answer 'y' to "Add another key?"
```

## Network Requirements

### Online Operations
- **Package Installation**: Internet required
- **Yubikey Registration**: Offline capable
- **Updates**: Internet recommended

### Proxy Considerations
```bash
# If behind proxy, set environment
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080
```

## Testing Environment

### Recommended Test Setup

#### Option 1: Virtual Machine
```bash
# Create test VM with same OS
# Snapshot before installation
# Test full workflow
```

#### Option 2: Docker Container
```bash
# Test basic functionality
docker run -it --privileged \
  -v /dev/bus/usb:/dev/bus/usb \
  ubuntu:22.04 bash
```

#### Option 3: Spare System
- Use non-critical system
- Full backup before testing
- Document all changes

## Verification Checklist

Before proceeding with installation:

- [ ] Yubikey detected: `lsusb | grep Yubico`
- [ ] Bash 5.0+: `bash --version`
- [ ] PAM installed: `ls /etc/pam.d/`
- [ ] Required packages: `which pamu2fcfg`
- [ ] Backup created: `ls /etc/pam.d.backup-*`
- [ ] Root access available: `sudo -v`
- [ ] Emergency access prepared
- [ ] Multiple Yubikeys available (recommended)

## Common Pre-Installation Issues

### Yubikey Not Detected
```bash
# Check USB connection
dmesg | tail -20

# Check for driver issues
sudo modprobe -r uhci_hcd
sudo modprobe uhci_hcd
```

### Package Conflicts
```bash
# Remove conflicting packages
sudo apt-get remove yubikey-personalization  # If conflicts

# Clean package cache
sudo apt-get clean
sudo apt-get update
```

### Permission Issues
```bash
# Fix USB permissions
sudo chmod 666 /dev/bus/usb/*/*

# Fix group membership
groups | grep plugdev || sudo usermod -a -G plugdev $USER
```

## Next Steps

Once all prerequisites are met:

1. Proceed to [Installation Guide](./installation.md)
2. Or jump to [Quick Start](./quick-start.md) for rapid setup
3. Review [Security Model](../architecture/security-model.md) for best practices
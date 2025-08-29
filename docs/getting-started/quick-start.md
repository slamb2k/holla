# Quick Start Guide

Get your Yubikey working with Linux PAM authentication in 5 minutes.

## Prerequisites Checklist

Before starting, ensure you have:
- ✅ A Yubikey with U2F support
- ✅ Root/sudo access
- ✅ Required packages installed (`libpam-u2f`, `pamu2fcfg`)

## Step 1: Install the Tool

```bash
# Clone and enter directory
git clone https://github.com/[org]/yubikey-pam-installer.git
cd yubikey-pam-installer

# Run quick install
sudo ./install.sh
```

## Step 2: Register Your Yubikey

Insert your Yubikey and run:

```bash
# Start registration wizard
./src/u2f_registration.sh

# Follow the prompts:
# 1. Insert Yubikey when prompted
# 2. Touch the Yubikey when it blinks
# 3. Registration completes automatically
```

## Step 3: Test Authentication

```bash
# Clear sudo cache
sudo -k

# Test authentication (Yubikey should blink)
sudo echo "Success!"

# Touch your Yubikey when it blinks
```

## That's It! 🎉

Your Yubikey is now configured for system authentication.

## Common Operations

### Add Another Yubikey
```bash
# Register additional backup key
./src/u2f_registration.sh
# Select "y" when asked to add another key
```

### Check Registration Status
```bash
# List registered keys
grep $USER ~/.config/Yubico/u2f_keys
```

### Temporary Disable (Emergency)
```bash
# Restore original PAM config
sudo ./uninstall.sh
```

## Quick Troubleshooting

### Yubikey Not Detected
```bash
# Check USB connection
lsusb | grep Yubico

# Restart udev
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Touch Not Registering
- Ensure you're touching the metal contact
- Try holding for 1-2 seconds
- Check LED is blinking

### Locked Out
1. Reboot to recovery mode
2. Run: `cp -r /etc/pam.d.backup-* /etc/pam.d`
3. Reboot normally

## What's Next?

### Essential Reading
- [Security Best Practices](../architecture/security-model.md)
- [Backup Key Setup](./prerequisites.md#backup-keys)
- [SSH Configuration](../integrations/ssh.md)

### Advanced Topics
- [Multiple User Setup](../deployment/configuration.md)
- [Desktop Integration](../integrations/desktop.md)
- [Troubleshooting Guide](../development/troubleshooting.md)

## Getting Help

- Check [Troubleshooting Guide](../development/troubleshooting.md)
- Review [Installation Guide](./installation.md) for detailed steps
- File issues at [GitHub Issues](https://github.com/[org]/yubikey-pam-installer/issues)
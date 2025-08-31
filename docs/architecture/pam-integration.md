# PAM Integration Architecture

Detailed explanation of how Yubikey PAM Installer integrates with Linux PAM (Pluggable Authentication Modules).

## PAM Overview

### What is PAM?

PAM (Pluggable Authentication Modules) is the authentication framework used by Linux systems. It provides a flexible mechanism for authenticating users through a stack of configurable modules.

### PAM Architecture

```
Application (sudo, login, ssh)
            ↓
        PAM Library
            ↓
    PAM Configuration
    (/etc/pam.d/service)
            ↓
      PAM Modules
    (pam_u2f.so, pam_unix.so)
```

## PAM Configuration Structure

### Service Files

Each service has its own PAM configuration:

```
/etc/pam.d/
├── sudo          # sudo command
├── su            # su command
├── login         # Console login
├── sshd          # SSH daemon
├── gdm           # GNOME Display Manager
├── lightdm       # LightDM
└── common-auth   # Shared authentication
```

### Configuration Format

```bash
# Format: type control-flag module [options]
auth    required    pam_env.so
auth    sufficient  pam_u2f.so authfile=/etc/u2f_keys
auth    required    pam_unix.so nullok try_first_pass
```

#### Module Types

- **auth**: Authentication (verify identity)
- **account**: Account validation (is account valid?)
- **password**: Password management
- **session**: Session setup/cleanup

#### Control Flags

- **required**: Must succeed, continue stack
- **requisite**: Must succeed, fail immediately if not
- **sufficient**: Success is enough, skip rest
- **optional**: Success/failure doesn't matter

## U2F Integration Design

### Module Stack Order

The order of PAM modules is critical:

```bash
# Optimal configuration
auth    required    pam_env.so           # 1. Environment setup
auth    sufficient  pam_u2f.so cue       # 2. Try Yubikey first
auth    required    pam_unix.so          # 3. Fall back to password
```

### Why This Order?

1. **pam_env.so first**: Sets up environment variables
2. **pam_u2f.so with sufficient**: If Yubikey succeeds, authentication complete
3. **pam_unix.so as fallback**: Password authentication if Yubikey fails

## Implementation Details

### Parser Module (`pam_parser.sh`)

```bash
# Key functions
parse_pam_line()      # Parse individual PAM lines
find_insertion_point() # Find where to insert pam_u2f
validate_pam_syntax()  # Ensure valid configuration
```

#### Insertion Logic

```bash
# Priority order for insertion point:
1. After pam_env.so (optimal)
2. Before pam_unix.so (good)
3. After first auth line (fallback)
```

### Configuration Modification

```bash
# Safe modification process
1. Parse existing configuration
2. Validate syntax
3. Create backup
4. Find insertion point
5. Insert pam_u2f line
6. Verify new configuration
7. Test authentication
```

## U2F Module Configuration

### pam_u2f.so Options

```bash
auth sufficient pam_u2f.so \
  authfile=/etc/u2f_keys \    # Key file location
  cue \                        # Show touch prompt
  origin=pam://hostname \      # Origin for U2F
  appid=pam://hostname \       # Application ID
  timeout=30                   # Touch timeout
```

### Key File Format

```
# ~/.config/Yubico/u2f_keys
username:credential:key_handle[:credential2:key_handle2...]
```

Example:

```
john:BJkQhw...xyz:r6sWwB...123:AnotherCred:AnotherHandle
```

## Authentication Flow

### Successful Authentication

```mermaid
User → sudo command
    ↓
PAM → pam_env.so (setup)
    ↓
PAM → pam_u2f.so (check key)
    ↓
Yubikey blinks
    ↓
User touches Yubikey
    ↓
pam_u2f.so → SUCCESS
    ↓
Authentication complete
```

### Fallback Flow

```mermaid
User → sudo command
    ↓
PAM → pam_u2f.so (check key)
    ↓
Timeout or 3 failures
    ↓
PAM → pam_unix.so (password)
    ↓
User enters password
    ↓
Authentication complete
```

## Service-Specific Configurations

### sudo Configuration

```bash
# /etc/pam.d/sudo
#%PAM-1.0
auth       required   pam_env.so
auth       sufficient pam_u2f.so cue
auth       required   pam_unix.so nullok
account    required   pam_unix.so
password   required   pam_unix.so
session    required   pam_unix.so
```

### SSH Configuration

```bash
# /etc/pam.d/sshd
auth       required   pam_env.so
auth       sufficient pam_u2f.so cue [authpending_file=/tmp/sshd_u2f]
auth       required   pam_unix.so

# Also requires in /etc/ssh/sshd_config:
ChallengeResponseAuthentication yes
UsePAM yes
```

### Desktop Login (GDM)

```bash
# /etc/pam.d/gdm-password
auth       required   pam_env.so
auth       sufficient pam_u2f.so cue [interactive]
auth       required   pam_unix.so
```

## Security Considerations

### Attack Vectors

1. **PAM Bypass**: Misconfiguration could allow bypass
2. **Key File Access**: Improper permissions on u2f_keys
3. **Module Order**: Wrong order could skip U2F

### Mitigations

```bash
# Secure permissions
chmod 600 ~/.config/Yubico/u2f_keys
chmod 700 ~/.config/Yubico

# Validate configuration
pamtester sudo $USER authenticate

# Monitor auth logs
tail -f /var/log/auth.log
```

## Backup System Integration

### Backup Strategy

```bash
# Before modification
1. Create timestamped backup
2. Verify backup integrity
3. Log backup location

# After modification
1. Test authentication
2. Verify all services
3. Keep backup for rollback
```

### Restore Process

```bash
# Emergency restore
sudo cp -r /etc/pam.d.backup-* /etc/pam.d/

# Selective restore
sudo cp /etc/pam.d.backup-*/sudo /etc/pam.d/sudo
```

## Testing PAM Configuration

### Safe Testing Methods

```bash
# 1. Test service
sudo cp /etc/pam.d/sudo /etc/pam.d/test-yubikey
sudo pamtester test-yubikey $USER authenticate

# 2. Verify syntax
for file in /etc/pam.d/*; do
  echo "Checking $file..."
  # Parse and validate
done

# 3. Monitor logs
journalctl -f -u gdm
tail -f /var/log/auth.log
```

## Troubleshooting Integration

### Common Issues

#### Module Not Found

```bash
# Check module exists
ls /lib/*/security/pam_u2f.so

# Install if missing
sudo apt-get install libpam-u2f
```

#### Wrong Module Order

```bash
# Symptoms: Yubikey ignored
# Fix: Ensure pam_u2f before pam_unix
```

#### Permission Denied

```bash
# Check key file permissions
ls -la ~/.config/Yubico/u2f_keys

# Fix permissions
chmod 600 ~/.config/Yubico/u2f_keys
```

## Advanced Configuration

### Per-User Configuration

```bash
# Central mapping file
# /etc/u2f_mappings
user1:credential1:handle1
user2:credential2:handle2

# PAM configuration
auth sufficient pam_u2f.so authfile=/etc/u2f_mappings
```

### Conditional Authentication

```bash
# Require Yubikey only for specific users
auth [success=1 default=ignore] pam_succeed_if.so user ingroup yubikey-users
auth sufficient pam_u2f.so
```

## Next Steps

- [Security Model](./security-model.md) - Security implications
- [Component Overview](./components.md) - Detailed component docs
- [Authentication Flow](./auth-flow.md) - Complete auth workflow

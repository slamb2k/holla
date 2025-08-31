# Product Roadmap

## Phase 1: Core PAM Integration

**Goal:** Implement basic Yubikey U2F authentication for terminal-based logins
**Success Criteria:** Successfully authenticate sudo and su commands using Yubikey in terminal environments

### Features

- [ ] PAM configuration parser and validator - Parse existing PAM configs safely `S`
- [ ] U2F registration tool - Register Yubikey with user account `M`
- [ ] Basic PAM module integration - Configure pam_u2f for sudo/su `M`
- [ ] Configuration backup system - Backup and restore PAM configs `S`
- [ ] Terminal authentication flow - Handle Yubikey touch in CLI `M`
- [ ] Fallback to password after 3 failed attempts `S`

### Dependencies

- pam_u2f module installation
- libu2f-host library
- Yubikey hardware for testing

## Phase 2: Context-Aware Authentication

**Goal:** Implement intelligent detection and handling of different authentication contexts
**Success Criteria:** Seamless authentication experience across terminal, GUI, and SSH sessions

### Features

- [ ] Environment detection system - Detect terminal vs GUI vs SSH `M`
- [ ] GNOME authentication dialog integration - Use polkit for GUI auth `L`
- [ ] Terminal emulator detection - Identify terminal within desktop `S`
- [ ] Focus management for auth dialogs - Auto-focus auth windows `M`
- [ ] Visual feedback system - Show Yubikey LED status `S`
- [ ] Multi-service PAM configuration - Configure gdm, lightdm, etc. `M`
- [ ] SSH session handling - Special handling for remote sessions `M`

### Dependencies

- GNOME polkit integration
- D-Bus communication
- X11/Wayland display detection

## Phase 3: Production Readiness

**Goal:** Ensure reliability, safety, and ease of deployment
**Success Criteria:** Zero-risk installation process with comprehensive recovery options

### Features

- [ ] Automated installer script - One-command installation `M`
- [ ] Pre-flight compatibility checks - Verify system requirements `S`
- [ ] Emergency recovery mode - Boot-time override option `L`
- [ ] Comprehensive audit logging - Log all auth attempts `M`
- [ ] System package creation - Build .deb/.rpm packages `M`
- [ ] Configuration management CLI - Manage settings post-install `S`
- [ ] Documentation and man pages - Complete usage documentation `S`

### Dependencies

- Systemd service files
- Package build infrastructure
- Distribution testing environments

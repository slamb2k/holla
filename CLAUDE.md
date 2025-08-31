# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Yubikey PAM Installer** - A terminal-based Linux configuration tool for integrating Yubikey U2F hardware tokens with PAM (Pluggable Authentication Modules). The tool provides automated, context-aware setup with intelligent fallback mechanisms for hardware-based two-factor authentication across all system logins.

## Project Architecture

### Technology Stack

- **Primary Language**: Bash shell scripting (5.0+)
- **PAM Integration**: pam_u2f and pam_yubico modules
- **GUI Dialogs**: GNOME Polkit authentication dialogs
- **Configuration**: Direct manipulation of /etc/pam.d/* files
- **Testing**: Bash Automated Testing System (bats)
- **Packaging**: System packages via fpm (deb/rpm/pacman)

### Key System Components

- **PAM Configuration**: Modifies files in /etc/pam.d/ for sudo, su, gdm, lightdm, SSH
- **U2F Registration**: Uses pamu2fcfg for Yubikey registration with user accounts
- **Environment Detection**: Detects terminal vs GUI vs SSH contexts for appropriate auth prompts
- **Fallback Mechanism**: Password authentication after 3 failed Yubikey attempts

## Development Commands

### Code Quality

```bash
# Static analysis for shell scripts
shellcheck *.sh

# Format shell scripts
shfmt -i 2 -w *.sh

# Run tests (when implemented)
bats test/*.bats
```

### Building & Packaging

```bash
# Create system package (requires fpm)
make package  # Creates .deb/.rpm packages

# Install locally for testing
sudo ./install.sh

# Uninstall/restore original PAM configs
sudo ./uninstall.sh
```

### Testing PAM Configuration

```bash
# Test sudo authentication
sudo -k && sudo echo "Auth successful"

# Test su authentication
su -c "echo 'Auth successful'"

# Verify PAM configuration syntax
sudo pamtester sudo $USER authenticate
```

## Agent OS Integration

This project uses Agent OS for project management and AI-assisted development.

### Product Documentation

- `.agent-os/product/mission.md` - Full product vision and features
- `.agent-os/product/mission-lite.md` - Condensed mission for AI context
- `.agent-os/product/tech-stack.md` - Complete technical stack
- `.agent-os/product/roadmap.md` - Three-phase development plan

### Development Workflow

1. Use `/create-spec` to generate feature specifications from roadmap items
2. Use `/create-tasks` to break specs into implementation tasks
3. Use `/execute-tasks` to implement features with AI assistance

### Code Style Guidelines

- **Bash Scripts**: Follow shellcheck recommendations
- **Indentation**: 2 spaces (never tabs)
- **Variables**: Use snake_case for variables, UPPER_SNAKE_CASE for constants
- **Error Handling**: Always check command exit codes, provide clear error messages
- **PAM Safety**: Always backup configs before modification, test in isolated environment first

## Critical PAM Safety Considerations

**WARNING**: PAM misconfiguration can lock you out of your system permanently.

### Before ANY PAM Changes

1. Create backup: `sudo cp -r /etc/pam.d /etc/pam.d.backup-$(date +%Y%m%d)`
2. Keep root terminal open: `sudo -s` in separate terminal
3. Test in VM/container first
4. Never close all terminals until changes verified

### Recovery Procedures

- Boot to recovery mode if locked out
- Mount root filesystem and restore /etc/pam.d.backup-*
- Or add `init=/bin/bash` to kernel parameters for emergency shell

## Project-Specific Context

### Authentication Flow States

1. **Terminal (TTY)**: Direct keyboard input, no GUI
2. **Terminal in Desktop**: Terminal emulator with GUI available
3. **GUI Application**: Polkit dialogs for authentication
4. **SSH Session**: Remote authentication considerations

### Yubikey U2F Implementation

- Registration stored in `~/.config/Yubico/u2f_keys`
- PAM stack order: pam_u2f.so → pam_unix.so (fallback)
- Touch timeout: 30 seconds default
- LED feedback via libu2f-host

### File Locations

- PAM configs: `/etc/pam.d/*`
- U2F mappings: `~/.config/Yubico/u2f_keys`
- System backup: `/etc/pam.d.backup-*`
- Audit logs: `/var/log/auth.log`

### Documentation Structure

The project documentation has been reorganized for better AI agent access:

```text
docs/
├── INDEX.md                  # Main documentation index
├── getting-started/          # Setup and prerequisites
├── development/             # Development guides
├── architecture/            # System architecture
├── deployment/              # Deployment procedures
├── integrations/            # External services
├── api/                     # API documentation
└── temporary/               # Work-in-progress and migration docs
```

For comprehensive documentation navigation, see [/docs/INDEX.md](/docs/INDEX.md).

### Documentation Guidelines for AI Agents

When agents are creating documentation (only when explicitly requested by the user):

1. **Check existing structure first**: Run `find docs -type f -name "*.md" | sort` to see current organization
2. **Use appropriate subfolders**:
   - `docs/deployment/` - CI/CD, deployment procedures, workflows
   - `docs/development/` - Development guides, local setup, troubleshooting
   - `docs/architecture/` - System design, AWS infrastructure
   - `docs/api/` - API references, endpoints, authentication
   - `docs/integrations/` - External service configurations
   - `docs/temporary/` - Work-in-progress, migration plans, optimization tasks
3. **Never place docs in docs/ root**: Always use the appropriate subfolder
4. **Update INDEX.md**: Add new docs to `/docs/INDEX.md` for navigation
5. **Consider merging**: Check if content fits in existing docs before creating new ones
6. **Check for duplicates**: Search existing docs for similar content with `grep -r "keyword" docs/`

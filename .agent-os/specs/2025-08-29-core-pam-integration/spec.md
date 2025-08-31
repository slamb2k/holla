# Spec Requirements Document

> Spec: Core PAM Integration
> Created: 2025-08-29

## Overview

Implement basic Yubikey U2F authentication for all PAM-based system logins including sudo, su, login, gdm, and SSH, with safe configuration parsing and automated backup mechanisms. This foundation will enable hardware-based two-factor authentication across the Linux system while preventing configuration errors that could lock users out.

## User Stories

### Safe PAM Configuration Management

As a system administrator, I want to safely parse and modify PAM configuration files, so that I can integrate Yubikey authentication without risking system lockout.

The administrator runs the installer script which first validates the existing PAM configuration syntax, creates a timestamped backup in /etc/pam.d.backup-YYYYMMDD-HHMMSS/, then carefully parses each service file to understand the current authentication stack. The parser identifies the optimal insertion point for the pam_u2f module, ensuring it's placed before pam_unix but after any critical system modules. If any syntax errors are detected, the process halts with clear error messages before any modifications are made.

### Yubikey Registration Workflow

As a Linux user, I want to register my Yubikey with my account, so that I can use it for system authentication.

The user runs the registration command which prompts them to insert their Yubikey. The tool uses pamu2fcfg to communicate with the hardware token, requesting the user to touch the device when its LED blinks. Upon successful touch, the U2F credentials are generated and stored in ~/.config/Yubico/u2f_keys with appropriate file permissions (0600). The user can register multiple keys for backup purposes, with each registration appending to the existing key file.

### Terminal Authentication Flow

As a terminal user, I want to authenticate with my Yubikey when using sudo or su, so that I have stronger security than passwords alone.

When the user types 'sudo command', the modified PAM configuration triggers U2F authentication. The terminal displays "Touch your Yubikey to authenticate..." and the Yubikey LED starts blinking. The user has 30 seconds to touch the device. If successful, the command proceeds. If the touch fails or times out, the system retries up to 3 times. After 3 failures, the system falls back to password authentication for that session only, displaying "Yubikey authentication failed. Please enter your password:". The next sudo command will attempt Yubikey authentication again.

## Spec Scope

1. **PAM Configuration Parser** - Parse and validate existing PAM configuration files with syntax checking and structure analysis
2. **Configuration Backup System** - Create timestamped directory copies of /etc/pam.d/ before any modifications
3. **U2F Registration Tool** - Command-line tool for registering Yubikeys with user accounts using pamu2fcfg
4. **PAM Module Integration** - Modify all PAM service files to include pam_u2f with proper stack ordering
5. **Session-Based Fallback** - Implement 3-attempt limit with password fallback per authentication session

## Out of Scope

- GUI authentication dialogs (Phase 2 feature)
- Context-aware environment detection (Phase 2 feature)
- Remote SSH session special handling (Phase 2 feature)
- System package creation and distribution (Phase 3 feature)
- Emergency recovery mode implementation (Phase 3 feature)

## Expected Deliverable

1. A bash script that successfully configures all PAM services to use Yubikey authentication with automatic backup creation
2. Command-line registration tool that stores U2F credentials in user home directories
3. Working authentication flow in terminal with 3-attempt Yubikey authentication and password fallback

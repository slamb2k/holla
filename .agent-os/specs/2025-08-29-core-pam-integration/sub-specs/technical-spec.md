# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-08-29-core-pam-integration/spec.md

## Technical Requirements

### PAM Configuration Parser

- Read and parse files in /etc/pam.d/ using bash built-in commands
- Validate PAM syntax: module-type control-flag module-path module-arguments
- Detect existing pam_u2f or pam_yubico entries to prevent duplicates
- Identify correct insertion point (after pam_env, before pam_unix)
- Support include and substack directives parsing
- Handle comments and blank lines preservation

### Backup System Implementation

- Create backup directory: /etc/pam.d.backup-$(date +%Y%m%d-%H%M%S)/
- Use cp -a to preserve permissions, ownership, and timestamps
- Verify backup completeness with diff comparison
- Store backup location in /var/log/yubikey-pam-installer.log
- Implement restore function using simple directory swap

### U2F Registration Interface

- Wrap pamu2fcfg command with error handling
- Create ~/.config/Yubico/ directory if not exists
- Set file permissions: chmod 0600 ~/.config/Yubico/u2f_keys
- Format: username:credential:key_handle (pamu2fcfg output format)
- Support multiple key registration with append mode
- Provide visual feedback during touch waiting period

### PAM Module Configuration

- Insert line: auth sufficient pam_u2f.so authfile=~/.config/Yubico/u2f_keys cue
- Target services: common-auth, sudo, su, login, gdm, lightdm, sshd
- Use 'sufficient' control flag for Phase 1 (allows fallback)
- Add 'cue' option to display "Please touch the device"
- Set timeout with 'timeout=30' parameter
- Position after pam_env.so, before pam_unix.so

### Fallback Mechanism

- Implement retry counter in PAM stack using pam_faillock
- Configure max_tries=3 for U2F attempts
- Add fallback line: auth required pam_unix.so try_first_pass
- Session-based: counter resets on successful auth
- Clear messaging: "Yubikey authentication failed (attempt X/3)"

### Error Handling

- Check for root/sudo privileges before modifications
- Verify pam_u2f.so module exists in /lib/*/security/
- Test PAM syntax with pamtester if available
- Rollback on any error using backup restore
- Log all operations to /var/log/yubikey-pam-installer.log

### Performance Criteria

- Backup creation: < 1 second for typical /etc/pam.d/
- Configuration parsing: < 100ms per file
- Registration process: < 5 seconds (excluding user interaction)
- Authentication timeout: 30 seconds default, configurable
- Fallback transition: < 1 second after final failure

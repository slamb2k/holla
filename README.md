# Yubikey PAM Configuration Installer

[![PR Validation](https://github.com/slamb2k/holla/actions/workflows/pr-validation.yml/badge.svg)](https://github.com/slamb2k/holla/actions/workflows/pr-validation.yml)
[![Build & Release](https://github.com/slamb2k/holla/actions/workflows/build-release.yml/badge.svg)](https://github.com/slamb2k/holla/actions/workflows/build-release.yml)
[![Security Scan](https://github.com/slamb2k/holla/actions/workflows/security-scan.yml/badge.svg)](https://github.com/slamb2k/holla/actions/workflows/security-scan.yml)

A secure Linux tool for integrating Yubikey U2F authentication with PAM (Pluggable Authentication Modules).

## Project Status

### ✅ Phase 1 - Task 1: PAM Configuration Parser (COMPLETE)

The PAM configuration parser and validator has been successfully implemented with the following features:

- **Syntax Validation**: Validates PAM configuration syntax including module types, control flags, and module paths
- **Configuration Analysis**: Analyzes PAM file structure and identifies optimal insertion points for U2F modules
- **Module Detection**: Detects existing pam_u2f or pam_yubico modules to prevent duplicates
- **Include Support**: Handles @include and substack directives properly
- **Safe Parsing**: Preserves comments, blank lines, and file structure

### ✅ Phase 1 - Task 2: Configuration Backup System (COMPLETE)

The backup and restore system has been successfully implemented with the following features:

- **Timestamped Backups**: Creates backups in format pam.d.backup-YYYYMMDD-HHMMSS
- **Permission Preservation**: Uses cp -a to maintain file permissions and attributes
- **Backup Verification**: Verifies backup integrity using diff
- **Restore Capability**: Safe restore with pre-restore safety backup
- **Metadata Storage**: Stores backup description, timestamp, and system info
- **Comprehensive Logging**: Logs all operations to yubikey-pam-installer.log
- **Disk Space Checks**: Validates sufficient space before backup operations

### ✅ Phase 1 - Task 3: U2F Registration Tool (COMPLETE)

The U2F registration tool has been successfully implemented with the following features:

- **Dependency Detection**: Checks for pamu2fcfg and provides install commands
- **Directory Management**: Creates ~/.config/Yubico with proper permissions (700)
- **Secure Key Storage**: Stores keys in u2f_keys with 600 permissions
- **Multi-Key Support**: Allows registration of multiple Yubikeys per user
- **Error Handling**: Comprehensive error messages for common issues
- **User Feedback**: Clear prompts and visual indicators during registration
- **Backup Creation**: Automatically backs up existing keys before modifications
- **Registration Wizard**: Interactive wizard for easy setup

## Components

### Core Parser (`src/pam_parser.sh`)

The main parser library providing these functions:

- `parse_pam_line()` - Parse individual PAM configuration lines
- `validate_pam_syntax()` - Validate PAM syntax for correctness
- `has_u2f_module()` - Detect U2F/Yubico modules in configuration
- `find_insertion_point()` - Find optimal location for U2F module insertion
- `parse_pam_file()` - Parse and analyze entire PAM files
- `validate_pam_file()` - Validate all lines in a PAM file
- `analyze_pam_structure()` - Provide detailed structure analysis

### Backup System (`src/backup_system.sh`)

The backup and restore library providing these functions:

- `create_backup_directory()` - Create timestamped backup directory
- `backup_pam_config()` - Backup PAM configuration with permission preservation
- `verify_backup()` - Verify backup integrity using diff
- `restore_from_backup()` - Restore PAM configuration from backup
- `save_backup_metadata()` - Store backup description and system info
- `list_backups()` - List all available backups
- `get_latest_backup()` - Retrieve the most recent backup
- `log_action()` - Log operations with timestamps
- `perform_safe_backup()` - Full backup with all safety checks
- `perform_safe_restore()` - Safe restore with pre-restore backup

### U2F Registration (`src/u2f_registration.sh`)

The Yubikey registration library providing these functions:

- `check_pamu2fcfg_installed()` - Check for required tools
- `get_install_command()` - Get distro-specific install command
- `create_yubico_directory()` - Create config directory with permissions
- `init_u2f_keys_file()` - Initialize keys file with proper permissions
- `parse_pamu2fcfg_output()` - Parse registration output
- `add_key_to_file()` - Add keys with multi-key support
- `check_existing_keys()` - Check for already registered keys
- `list_user_keys()` - Display registered keys for a user
- `register_yubikey()` - Main registration function
- `registration_wizard()` - Interactive setup wizard

### Testing

- `tests/test_pam_parser.bats` - Parser test suite (requires bats)
- `tests/test_backup_system.bats` - Backup system test suite (requires bats)
- `tests/test_u2f_registration.bats` - Registration test suite (requires bats)
- `simple_test.sh` - Standalone parser test runner (no dependencies)
- `simple_backup_test.sh` - Standalone backup test runner (no dependencies)
- `simple_registration_test.sh` - Standalone registration test runner (no dependencies)
- `demo_parser.sh` - Interactive demonstration of parser capabilities
- `demo_backup.sh` - Interactive demonstration of backup system
- `demo_registration.sh` - Interactive demonstration of registration system

## Usage

### Running Tests

```bash
# Run simple tests (no dependencies required)
./simple_test.sh

# Run full test suite (requires bats)
./run_tests.sh

# Run interactive demo
./demo_parser.sh
```

### Using the Parser

```bash
# Source the parser library
source src/pam_parser.sh

# Parse a PAM file
parse_pam_file /etc/pam.d/sudo

# Validate PAM syntax
validate_pam_file /etc/pam.d/sudo

# Analyze PAM structure
analyze_pam_structure /etc/pam.d/sudo

# Find insertion point for U2F module
find_insertion_point /etc/pam.d/sudo
```

## Test Results

### Parser Tests: 19/19 passing
- ✅ PAM line parsing (auth, account, password, session)
- ✅ Comment and blank line detection
- ✅ U2F module detection (pam_u2f, pam_yubico)
- ✅ Include directive parsing
- ✅ Complex control flag handling
- ✅ Syntax validation
- ✅ File parsing and analysis
- ✅ Insertion point detection

### Backup System Tests: 17/17 passing
- ✅ Timestamped directory creation
- ✅ File copy with permission preservation
- ✅ Backup verification with diff
- ✅ Restore from backup
- ✅ Metadata storage and retrieval
- ✅ Logging with timestamps
- ✅ Disk space validation
- ✅ Error handling and recovery

### U2F Registration Tests: 21/21 passing
- ✅ pamu2fcfg detection and installation
- ✅ Directory creation with permissions
- ✅ U2F keys file initialization
- ✅ pamu2fcfg output parsing
- ✅ Multi-key registration support
- ✅ Existing key detection
- ✅ Backup creation
- ✅ User feedback displays

## Next Steps

The remaining Phase 1 tasks to be implemented:

1. **Task 4**: PAM Module Integration
2. **Task 5**: Terminal Authentication Flow and Fallback

## Safety Note

⚠️ **WARNING**: PAM misconfiguration can lock you out of your system. This tool includes extensive validation and safety checks to prevent such issues. Always test in a VM or container first.

## License

[To be determined]
# Technical Stack

## Core Technologies

- **application_framework:** Bash shell scripting
- **database_system:** Flat files (/etc/pam.d/ configs)
- **javascript_framework:** n/a
- **import_strategy:** n/a
- **css_framework:** n/a
- **ui_component_library:** GNOME Authentication Dialogs (polkit)
- **fonts_provider:** System fonts
- **icon_library:** GNOME/Adwaita Icons
- **application_hosting:** Local system installation
- **database_hosting:** Local filesystem
- **asset_hosting:** Local filesystem
- **deployment_solution:** System package managers (apt/dnf/pacman)
- **code_repository_url:** https://github.com/[org]/yubikey-pam-installer

## System Integration

### PAM Modules
- **pam_u2f:** Core U2F authentication module
- **pam_yubico:** Yubikey-specific PAM module

### System Libraries
- **libu2f-host:** U2F host library for hardware communication
- **libfido2:** FIDO2/U2F protocol implementation
- **libpam:** PAM development libraries
- **yubikey-manager:** Command-line Yubikey management

### GUI Integration
- **GNOME Polkit:** Authentication agent for privilege escalation
- **pkexec:** Polkit execution wrapper
- **zenity:** GUI dialog creation from shell scripts
- **Wayland/X11:** Display server protocol support

### Shell Utilities
- **bash 5.0+:** Primary scripting language
- **sed/awk:** Text processing for PAM configs
- **systemctl:** Service management
- **dbus-send:** D-Bus communication for desktop integration

### Configuration Management
- **PAM configuration files:** /etc/pam.d/* management
- **systemd:** Service integration
- **udev rules:** Yubikey device detection

### Testing & Quality
- **bats:** Bash Automated Testing System
- **shellcheck:** Shell script static analysis
- **shfmt:** Shell script formatter

### Packaging & Distribution
- **fpm:** Multi-format package builder (deb, rpm, pacman)
- **systemd:** Service management files
- **man pages:** Documentation generation

### Development Tools
- **git:** Version control
- **make:** Build automation
- **docker:** Testing in clean environments
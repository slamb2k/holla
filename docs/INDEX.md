# Documentation Index

Welcome to the Yubikey PAM Installer documentation. This index provides navigation to all available documentation sections.

## 📚 Documentation Sections

### [Getting Started](./getting-started/)
Essential guides for new users and initial setup.

- [Installation Guide](./getting-started/installation.md) - System requirements and installation instructions
- [Quick Start](./getting-started/quick-start.md) - Get up and running in 5 minutes
- [Prerequisites](./getting-started/prerequisites.md) - Required software and hardware

### [Development](./development/)
Guides for developers contributing to the project.

- [Local Setup](./development/local-setup.md) - Setting up your development environment
- [Testing Guide](./development/testing.md) - Running tests and writing new test cases
- [Contributing](./development/contributing.md) - Contribution guidelines and code standards
- [Troubleshooting](./development/troubleshooting.md) - Common issues and solutions

### [Architecture](./architecture/)
Technical documentation about system design and implementation.

- [PAM Integration](./architecture/pam-integration.md) - How the tool integrates with Linux PAM
- [Security Model](./architecture/security-model.md) - Security considerations and threat model
- [Component Overview](./architecture/components.md) - Detailed component descriptions
- [Authentication Flow](./architecture/auth-flow.md) - Complete authentication workflow

### [Deployment](./deployment/)
Production deployment and packaging documentation.

- [Packaging Guide](./deployment/packaging.md) - Creating .deb/.rpm packages
- [System Integration](./deployment/system-integration.md) - Integrating with system services
- [Configuration Management](./deployment/configuration.md) - Managing configurations at scale
- [Rollback Procedures](./deployment/rollback.md) - Emergency recovery procedures

### [Integrations](./integrations/)
External service and tool integrations.

- [SSH Configuration](./integrations/ssh.md) - Configuring SSH with Yubikey
- [Desktop Environments](./integrations/desktop.md) - GNOME, KDE, and other DE integrations
- [Container Support](./integrations/containers.md) - Docker and Kubernetes considerations

### [API](./api/)
API references and technical specifications.

- [Shell Functions](./api/shell-functions.md) - Complete function reference
- [Configuration Format](./api/config-format.md) - Configuration file specifications
- [Exit Codes](./api/exit-codes.md) - Error codes and their meanings

### [Temporary](./temporary/)
Work-in-progress documentation and migration guides.

- Active development documentation
- Migration plans
- Experimental features

## 🔍 Quick Links

### Most Popular Pages
1. [Quick Start Guide](./getting-started/quick-start.md)
2. [Installation Guide](./getting-started/installation.md)
3. [Troubleshooting](./development/troubleshooting.md)
4. [Security Model](./architecture/security-model.md)

### For System Administrators
- [Installation Guide](./getting-started/installation.md)
- [Configuration Management](./deployment/configuration.md)
- [Rollback Procedures](./deployment/rollback.md)

### For Developers
- [Local Setup](./development/local-setup.md)
- [Testing Guide](./development/testing.md)
- [Component Overview](./architecture/components.md)

### For Security Auditors
- [Security Model](./architecture/security-model.md)
- [PAM Integration](./architecture/pam-integration.md)
- [Authentication Flow](./architecture/auth-flow.md)

## 📖 Documentation Standards

All documentation in this project follows these standards:

- **Markdown Format**: All docs use GitHub-flavored Markdown
- **Clear Structure**: Each document has a clear hierarchy with proper headings
- **Code Examples**: Include working code examples where applicable
- **Cross-References**: Link to related documentation
- **Keep Updated**: Documentation is updated alongside code changes

## 🤝 Contributing to Documentation

To contribute to the documentation:

1. Check existing structure: `find docs -type f -name "*.md" | sort`
2. Use appropriate subfolders (never place docs in root)
3. Update this INDEX.md when adding new documents
4. Consider if content fits in existing docs before creating new ones
5. Search for duplicates: `grep -r "keyword" docs/`

See [Contributing Guide](./development/contributing.md) for detailed guidelines.
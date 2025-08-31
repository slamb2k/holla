# Local Development Setup

Guide for setting up a development environment for the Yubikey PAM Installer project.

## Development Environment

### Required Tools

```bash
# Core development tools
sudo apt-get install -y \
  git \
  bash \
  make \
  shellcheck \
  shfmt

# Testing tools
sudo apt-get install -y \
  bats \
  docker.io

# Documentation tools
sudo apt-get install -y \
  pandoc \
  grip  # GitHub markdown preview
```

### Repository Setup

1. **Fork and Clone**:

   ```bash
   # Fork on GitHub first, then:
   git clone https://github.com/YOUR_USERNAME/yubikey-pam-installer.git
   cd yubikey-pam-installer
   # Add upstream remote
   git remote add upstream https://github.com/[org]/yubikey-pam-installer.git
   ```

2. **Branch Setup**:

   ```bash
   # Create feature branch
   git checkout -b feature/your-feature-name
   # Keep main branch clean
   git checkout main
   git pull upstream main
   ```

## Project Structure

```
yubikey-pam-installer/
├── src/                    # Source code
│   ├── pam_parser.sh      # PAM configuration parser
│   ├── backup_system.sh   # Backup and restore
│   └── u2f_registration.sh # Yubikey registration
├── tests/                  # Test suites
│   ├── test_pam_parser.bats
│   ├── test_backup_system.bats
│   └── test_u2f_registration.bats
├── docs/                   # Documentation
│   ├── INDEX.md
│   ├── getting-started/
│   ├── development/
│   └── ...
├── demo_*.sh              # Demonstration scripts
├── simple_*_test.sh       # Standalone test runners
└── CLAUDE.md              # AI assistant guidelines
```

## Development Workflow

### 1. Code Style

#### Shell Script Standards

```bash
# Check syntax with shellcheck
shellcheck src/*.sh

# Format with shfmt (2 space indent)
shfmt -i 2 -w src/*.sh

# Naming conventions
snake_case_functions()
UPPER_CASE_CONSTANTS
lower_case_variables
```

#### Best Practices

- Always quote variables: `"$variable"`
- Use `[[ ]]` instead of `[ ]` for conditionals
- Check exit codes: `command || handle_error`
- Add error handling: `set -euo pipefail`

### 2. Testing

#### Running Tests

```bash
# Run all tests
bats tests/*.bats

# Run specific test suite
bats tests/test_pam_parser.bats

# Run standalone tests (no bats required)
./simple_test.sh
./simple_backup_test.sh
./simple_registration_test.sh

# Run demonstrations
./demo_parser.sh
./demo_backup.sh
./demo_registration.sh
```

#### Writing Tests

Example test structure:

```bash
#!/usr/bin/env bats

setup() {
  # Test setup
  source "${BATS_TEST_DIRNAME}/../src/module.sh"
  TEST_DIR=$(mktemp -d)
}

teardown() {
  # Cleanup
  rm -rf "$TEST_DIR"
}

@test "description of test" {
  # Arrange
  input="test input"
  # Act
  run function_to_test "$input"
  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" =~ "expected" ]]
}
```

### 3. Debugging

#### Debug Mode

```bash
# Enable debug output
set -x  # Print commands
set -v  # Print script lines

# Or run with debug
bash -x src/script.sh
```

#### Logging

```bash
# Add debug logging
debug_log() {
  [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2
}

# Use in code
debug_log "Variable value: $var"

# Run with debug enabled
DEBUG=1 ./script.sh
```

## Testing with Docker

### Safe PAM Testing

Create a Docker test environment:

```dockerfile
# Dockerfile.test
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
  libpam-u2f \
  pamu2fcfg \
  sudo \
  bash

COPY . /app
WORKDIR /app

RUN chmod +x src/*.sh
```

Build and test:

```bash
# Build test container
docker build -f Dockerfile.test -t yubikey-test .

# Run tests in container
docker run --rm -it \
  --device /dev/bus/usb \
  yubikey-test \
  bats tests/*.bats
```

## Mock Yubikey Testing

For development without physical Yubikey:

```bash
# Create mock pamu2fcfg
cat > mock_pamu2fcfg.sh << 'EOF'
#!/bin/bash
# Mock pamu2fcfg for testing
echo "testuser:mockcred:mockhandle"
exit 0
EOF

# Use in tests
export PATH=".:$PATH"
mv mock_pamu2fcfg.sh pamu2fcfg
chmod +x pamu2fcfg
```

## Git Workflow

### Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Testing
- `refactor`: Code refactoring
- `chore`: Maintenance

Example:

```bash
git commit -m "feat(registration): add multi-key support

- Allow multiple Yubikeys per user
- Implement append mode for keys
- Add backup key prompts

Closes #123"
```

### Pull Request Process

1. **Before PR**:

   ```bash
   # Update from upstream
   git fetch upstream
   git rebase upstream/main
   # Run tests
   bats tests/*.bats
   # Check code quality
   shellcheck src/*.sh
   ```

2. **Create PR**:
   - Clear title and description
   - Reference related issues
   - Include test results
   - Add screenshots if UI changes

## Development Tips

### 1. PAM Safety

Always test PAM changes in isolation:

```bash
# Create test PAM service
sudo cp /etc/pam.d/sudo /etc/pam.d/test-yubikey

# Test with pamtester
sudo pamtester test-yubikey $USER authenticate
```

### 2. Quick Iteration

Use the demo scripts for rapid testing:

```bash
# Modify source
vim src/pam_parser.sh

# Test immediately
./demo_parser.sh
```

### 3. Documentation

Update docs alongside code:

```bash
# Check for outdated docs
grep -r "function_name" docs/

# Preview markdown
grip docs/development/local-setup.md
# Open http://localhost:6419
```

## Troubleshooting Development Issues

### Permission Errors

```bash
# Fix script permissions
chmod +x src/*.sh *.sh

# Fix test permissions
chmod +x tests/*.bats
```

### Test Failures

```bash
# Run with verbose output
bats --verbose tests/test_file.bats

# Debug specific test
bash -x tests/test_file.bats
```

### Shellcheck Warnings

```bash
# Ignore specific warning
# shellcheck disable=SC2034
unused_var="value"

# Check specific file
shellcheck -x src/specific.sh
```

## Next Steps

- Review [Testing Guide](./testing.md) for comprehensive testing
- Read [Contributing Guidelines](./contributing.md) before submitting PRs
- Check [Architecture Overview](../architecture/components.md) for system design

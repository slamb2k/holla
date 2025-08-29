# Testing Guide

Comprehensive guide for testing the Yubikey PAM Installer.

## Test Structure

### Test Organization

```
tests/
├── test_pam_parser.bats      # PAM parser tests
├── test_backup_system.bats   # Backup system tests
├── test_u2f_registration.bats # Registration tests
└── test_integration.bats     # Integration tests (future)

simple_*.sh                   # Standalone test runners
demo_*.sh                     # Interactive demonstrations
```

### Test Coverage

Current test coverage by component:

| Component | Tests | Coverage |
|-----------|-------|----------|
| PAM Parser | 19 | Core functionality |
| Backup System | 17 | All operations |
| U2F Registration | 21 | Registration workflow |
| **Total** | **57** | **~85%** |

## Running Tests

### Using BATS (Recommended)

```bash
# Install bats
sudo apt-get install bats  # Debian/Ubuntu
sudo dnf install bats       # Fedora

# Run all tests
bats tests/*.bats

# Run specific test file
bats tests/test_pam_parser.bats

# Verbose output
bats --verbose tests/*.bats

# TAP format output
bats --tap tests/*.bats
```

### Using Standalone Tests

No dependencies required:

```bash
# Run individual test suites
./simple_test.sh              # PAM parser tests
./simple_backup_test.sh       # Backup tests
./simple_registration_test.sh # Registration tests

# Run all standalone tests
for test in simple_*_test.sh; do
  echo "Running $test..."
  ./$test || exit 1
done
```

### Using Demo Scripts

Interactive testing:

```bash
# Test components interactively
./demo_parser.sh       # PAM parser demo
./demo_backup.sh       # Backup system demo
./demo_registration.sh # Registration demo
```

## Writing Tests

### BATS Test Structure

```bash
#!/usr/bin/env bats

# Setup runs before each test
setup() {
  # Source the module to test
  source "${BATS_TEST_DIRNAME}/../src/module.sh"
  
  # Create test environment
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
}

# Teardown runs after each test
teardown() {
  # Cleanup
  rm -rf "$TEST_DIR"
}

# Test case
@test "descriptive test name" {
  # Arrange
  local input="test data"
  local expected="expected output"
  
  # Act
  run function_to_test "$input"
  
  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" =~ "$expected" ]]
}
```

### Test Best Practices

#### 1. Test Naming
```bash
# Good test names
@test "parse valid PAM auth line with multiple arguments" { }
@test "backup preserves file permissions (600)" { }
@test "registration fails with invalid Yubikey output" { }

# Bad test names
@test "test1" { }
@test "it works" { }
```

#### 2. Assertions
```bash
# Check exit status
[ "$status" -eq 0 ]      # Success
[ "$status" -eq 1 ]      # Failure

# Check output contains
[[ "$output" =~ "pattern" ]]

# Check exact output
[ "$output" = "exact match" ]

# Check file exists
[ -f "$file_path" ]

# Check directory exists
[ -d "$dir_path" ]

# Check permissions
[ "$(stat -c %a "$file")" = "600" ]
```

#### 3. Test Isolation
```bash
setup() {
  # Create isolated environment
  TEST_DIR=$(mktemp -d)
  TEST_HOME="$TEST_DIR/home"
  
  # Override environment
  export HOME="$TEST_HOME"
  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
  # Restore environment
  export HOME="$ORIGINAL_HOME"
  
  # Cleanup
  rm -rf "$TEST_DIR"
}
```

## Test Categories

### Unit Tests

Test individual functions:

```bash
@test "parse_pam_line handles comments" {
  run parse_pam_line "# This is a comment"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type:comment" ]]
}
```

### Integration Tests

Test component interactions:

```bash
@test "backup and restore workflow" {
  # Create backup
  run create_backup_directory "$TEST_DIR"
  [ "$status" -eq 0 ]
  backup_dir="$output"
  
  # Backup files
  run backup_pam_config "$SOURCE" "$backup_dir"
  [ "$status" -eq 0 ]
  
  # Verify backup
  run verify_backup "$SOURCE" "$backup_dir"
  [ "$status" -eq 0 ]
  
  # Restore
  run restore_from_backup "$backup_dir" "$TARGET"
  [ "$status" -eq 0 ]
}
```

### Mock Testing

Testing without real dependencies:

```bash
# Mock external commands
setup() {
  # Create mock pamu2fcfg
  cat > "$TEST_DIR/pamu2fcfg" << 'EOF'
#!/bin/bash
echo "user:credential:handle"
exit 0
EOF
  chmod +x "$TEST_DIR/pamu2fcfg"
  export PATH="$TEST_DIR:$PATH"
}

@test "registration with mock Yubikey" {
  run register_yubikey "testuser"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "successfully registered" ]]
}
```

## Testing PAM Safely

### Using pamtester

```bash
# Install pamtester
sudo apt-get install pamtester

# Create test PAM service
sudo cp /etc/pam.d/sudo /etc/pam.d/test-service

# Test authentication
pamtester test-service $USER authenticate

# Test with specific modules
echo "auth required pam_u2f.so" | sudo tee /etc/pam.d/test-service
pamtester test-service $USER authenticate
```

### Docker Testing

```bash
# Create test container
docker run -it --rm \
  -v $(pwd):/app \
  -w /app \
  ubuntu:22.04 \
  bash -c "
    apt-get update && \
    apt-get install -y libpam-u2f bats && \
    bats tests/*.bats
  "
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y bats shellcheck libpam-u2f
    
    - name: Run shellcheck
      run: shellcheck src/*.sh
    
    - name: Run tests
      run: bats tests/*.bats
    
    - name: Run standalone tests
      run: |
        ./simple_test.sh
        ./simple_backup_test.sh
        ./simple_registration_test.sh
```

## Test Data

### Sample PAM Configurations

```bash
# Create test PAM files
create_test_pam_files() {
  cat > "$TEST_DIR/sudo" << 'EOF'
#%PAM-1.0
auth       required   pam_env.so
auth       required   pam_unix.so nullok
account    required   pam_unix.so
password   required   pam_unix.so
session    required   pam_unix.so
EOF
}
```

### Mock Yubikey Data

```bash
# Mock registration data
MOCK_USER="testuser"
MOCK_CREDENTIAL="vwZ3YnVNTUlHZGljRm5jNmJTODQyMjJGVFlIdkpGZ0FYRw"
MOCK_HANDLE="bhyom5YebxjslOdyynCgMiBFQTKCHgrqNzGzyoRqTOWaPibe"
MOCK_REGISTRATION="$MOCK_USER:$MOCK_CREDENTIAL:$MOCK_HANDLE"
```

## Debugging Tests

### Verbose Output

```bash
# BATS verbose mode
bats --verbose tests/test_file.bats

# Debug specific test
bats tests/test_file.bats --filter "test name"

# Show all output
bats tests/test_file.bats --show-output-of-passing-tests
```

### Interactive Debugging

```bash
# Add debugging to test
@test "debug example" {
  # Print variables
  echo "Variable: $var" >&3
  
  # Pause for inspection
  read -p "Press enter to continue..." >&3
  
  # Check state
  ls -la "$TEST_DIR" >&3
}
```

### Common Test Issues

#### Permission Errors
```bash
# Fix in setup()
chmod 600 "$TEST_FILE"
chmod 700 "$TEST_DIR"
```

#### Race Conditions
```bash
# Add sleep for timing issues
sleep 0.1

# Or use retry logic
retry() {
  local n=1
  local max=5
  while ! "$@"; do
    if [[ $n -lt $max ]]; then
      ((n++))
      sleep 0.1
    else
      return 1
    fi
  done
}
```

#### Environment Pollution
```bash
# Save and restore environment
setup() {
  ORIGINAL_HOME="$HOME"
  ORIGINAL_PATH="$PATH"
}

teardown() {
  export HOME="$ORIGINAL_HOME"
  export PATH="$ORIGINAL_PATH"
}
```

## Performance Testing

### Timing Tests

```bash
@test "performance: parser handles large file" {
  # Create large test file
  for i in {1..1000}; do
    echo "auth required pam_unix.so" >> "$TEST_FILE"
  done
  
  # Time the operation
  run time parse_pam_file "$TEST_FILE"
  
  # Check completed within timeout
  [ "$status" -eq 0 ]
  
  # Could also check actual time if needed
  # [[ "$output" =~ "real.*0m0" ]]  # Under 1 second
}
```

## Test Reporting

### Generate Coverage Report

```bash
#!/bin/bash
# test_coverage.sh

total=0
passed=0

for test in tests/*.bats; do
  echo "Running $(basename "$test")..."
  if bats "$test"; then
    ((passed++))
  fi
  ((total++))
done

echo "Coverage: $passed/$total tests passed"
echo "Percentage: $((passed * 100 / total))%"
```

## Next Steps

- Review [Local Setup](./local-setup.md) for development environment
- Read [Contributing Guidelines](./contributing.md) for code standards
- Check [Troubleshooting](./troubleshooting.md) for common issues
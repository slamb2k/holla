# Spec Tasks

## Tasks

- [ ] 1. PAM Configuration Parser and Validator
  - [ ] 1.1 Write tests for PAM syntax validation
  - [ ] 1.2 Implement PAM file parser with syntax checking
  - [ ] 1.3 Create configuration structure analyzer
  - [ ] 1.4 Add module detection for pam_u2f/pam_yubico
  - [ ] 1.5 Implement insertion point identification logic
  - [ ] 1.6 Add include/substack directive support
  - [ ] 1.7 Verify all parser tests pass

- [ ] 2. Configuration Backup System
  - [ ] 2.1 Write tests for backup creation and restoration
  - [ ] 2.2 Implement timestamped directory creation
  - [ ] 2.3 Add file copy with permission preservation
  - [ ] 2.4 Create backup verification with diff
  - [ ] 2.5 Implement logging to yubikey-pam-installer.log
  - [ ] 2.6 Add restore function from backup
  - [ ] 2.7 Verify all backup tests pass

- [ ] 3. U2F Registration Tool
  - [ ] 3.1 Write tests for registration workflow
  - [ ] 3.2 Check and install pamu2fcfg if missing
  - [ ] 3.3 Create ~/.config/Yubico directory structure
  - [ ] 3.4 Implement pamu2fcfg wrapper with error handling
  - [ ] 3.5 Add multi-key registration support
  - [ ] 3.6 Set proper file permissions (0600)
  - [ ] 3.7 Add user feedback during touch waiting
  - [ ] 3.8 Verify all registration tests pass

- [ ] 4. PAM Module Integration
  - [ ] 4.1 Write tests for PAM modification logic
  - [ ] 4.2 Create service file list (common-auth, sudo, su, etc.)
  - [ ] 4.3 Implement pam_u2f line insertion logic
  - [ ] 4.4 Add configuration for each PAM service
  - [ ] 4.5 Set proper control flags and parameters
  - [ ] 4.6 Implement rollback on error
  - [ ] 4.7 Test authentication with modified configs
  - [ ] 4.8 Verify all integration tests pass

- [ ] 5. Terminal Authentication Flow and Fallback
  - [ ] 5.1 Write tests for authentication flow
  - [ ] 5.2 Implement 3-attempt retry logic
  - [ ] 5.3 Add clear user prompts and feedback
  - [ ] 5.4 Create session-based fallback to password
  - [ ] 5.5 Test timeout handling (30 seconds)
  - [ ] 5.6 Verify sudo/su authentication works
  - [ ] 5.7 Test all PAM services authentication
  - [ ] 5.8 Verify all authentication tests pass

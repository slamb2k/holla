# Deployment Automation

This guide covers automated deployment workflows and CI/CD integration for the Yubikey PAM Installer.

## Overview

The project includes comprehensive automation for:
- Testing across multiple environments
- Package building and distribution
- Release management
- Containerized testing
- Quality assurance checks

## Deployment Script

### Usage

The `deploy.sh` script provides a unified interface for all deployment operations:

```bash
# Check deployment readiness
./deploy.sh check

# Run comprehensive tests
./deploy.sh test

# Build all packages
./deploy.sh build

# Deploy to staging
./deploy.sh stage

# Create a release
./deploy.sh release 1.0.0

# Run complete pipeline
./deploy.sh full
```

### Environment Variables

Control deployment behavior with environment variables:

```bash
# Skip time-consuming tests
SKIP_TESTS=1 ./deploy.sh build

# Skip package building
SKIP_PACKAGES=1 ./deploy.sh stage

# Target specific environment
DEPLOYMENT_ENV=staging ./deploy.sh stage
```

## CI/CD Workflows

### GitHub Actions Integration

#### PR Validation Pipeline

Triggered on pull requests to `main` or `develop`:

```yaml
# .github/workflows/pr-validation.yml
- Lint checks (ShellCheck)
- Format validation (shfmt)
- Security scanning (Trivy)
- Documentation validation
- Unit tests (bats)
- Integration tests
- Multi-OS compatibility checks
```

**Matrix Testing:**
- Ubuntu 20.04, 22.04, 24.04
- Bash 5.0+ compatibility
- PAM dependency verification

#### Docker Test Matrix

Comprehensive containerized testing:

```yaml
# .github/workflows/docker-test.yml
- Multi-platform builds
- Ubuntu version matrix testing
- Security vulnerability scanning
- Package installation simulation
```

#### Build & Release Pipeline

Automated on pushes to `main` and version tags:

```yaml
# .github/workflows/build-release.yml
- Full validation suite
- Package building (DEB, RPM, Arch)
- Docker image creation
- GitHub release creation
- Artifact upload
```

### Branch Strategy

```
main
├── feat/feature-name       # Feature branches
├── fix/bug-description     # Bug fixes  
├── hotfix/critical-fix     # Emergency fixes
└── develop                 # Integration branch
```

## Testing Strategy

### Test Levels

#### 1. Unit Tests
- Individual component testing
- Mock PAM environment
- Isolated function validation
- Fast execution (< 30s)

```bash
# Run unit tests
make test
./simple_test.sh
./simple_backup_test.sh
./simple_registration_test.sh
```

#### 2. Integration Tests
- Component interaction testing
- Real PAM parsing (safe mode)
- Backup/restore workflows
- Demo script execution

```bash
# Run integration tests
./demo_parser.sh
./demo_backup.sh
./demo_registration.sh  # Hardware required
```

#### 3. Container Tests
- Clean environment testing
- Multi-distribution validation
- Package installation testing
- Security scanning

```bash
# Run container tests
make docker-test
make docker-compose-test
```

#### 4. End-to-End Tests
- Full system integration
- Real hardware authentication
- Production scenario simulation
- Manual validation required

### Test Data Management

#### Mock Data Structure
```
tests/fixtures/
├── pam.d/                  # Sample PAM configs
│   ├── sudo
│   ├── su
│   ├── gdm3
│   └── sshd
├── u2f_keys/              # Sample key files
│   ├── valid_key
│   └── invalid_key
└── backups/               # Sample backup dirs
    └── pam.d.backup-20240829/
```

## Package Management

### Build Matrix

| Format | Target | Tool | CI/CD |
|--------|--------|------|-------|
| DEB | Debian/Ubuntu | fpm | ✅ |
| RPM | Fedora/RHEL | fpm | ✅ |
| PKG | Arch Linux | fpm | ✅ |
| TAR | Universal | tar | ✅ |
| Docker | Container | docker | ✅ |

### Versioning Strategy

**Semantic Versioning (SemVer):**
- `MAJOR.MINOR.PATCH`
- Pre-release: `1.0.0-alpha.1`
- Build metadata: `1.0.0+20240829.abc123`

**Version Bumping:**
```bash
# Automated version bump
make release-patch   # 1.0.0 → 1.0.1
make release-minor   # 1.0.0 → 1.1.0
make release-major   # 1.0.0 → 2.0.0
```

### Package Distribution

#### Direct Distribution
```bash
# GitHub Releases
gh release create v1.0.0 dist/*

# Manual upload
curl -X POST -H "Authorization: token $TOKEN" \
     -H "Content-Type: application/octet-stream" \
     --data-binary @package.deb \
     "https://uploads.github.com/repos/user/repo/releases/123/assets?name=package.deb"
```

#### Repository Distribution
```bash
# APT repository
./deploy.sh build
./scripts/create-apt-repo.sh dist/*.deb

# YUM repository  
./scripts/create-yum-repo.sh dist/*.rpm

# AUR package
./scripts/update-aur.sh
```

## Environment Management

### Staging Environment

**Docker-based staging:**
```bash
# Start staging environment
docker-compose -f docker-compose.staging.yml up -d

# Deploy to staging
./deploy.sh stage

# Test staging deployment
docker exec staging-container /usr/share/yubikey-pam-installer/test.sh

# Clean staging
docker-compose -f docker-compose.staging.yml down --volumes
```

### Production Considerations

#### Pre-deployment Checklist
- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version tagged in git
- [ ] Security scan passed
- [ ] Backup procedures tested

#### Rollback Procedures
```bash
# Git rollback
git tag -d v1.0.1
git push origin :refs/tags/v1.0.1
git revert HEAD~1

# Package rollback  
sudo apt-get install yubikey-pam-installer=1.0.0-1

# Emergency PAM restore
sudo cp -r /etc/pam.d.backup-20240829/* /etc/pam.d/
```

## Monitoring & Alerting

### Build Health Monitoring

#### GitHub Actions Status
- Workflow success/failure notifications
- Performance regression detection
- Test coverage tracking

#### Package Quality Metrics
- Linting score trends
- Test coverage percentage
- Security vulnerability count
- Documentation completeness

### Deployment Metrics

#### Success Indicators
- Package installation success rate
- PAM configuration success rate
- User registration success rate
- Authentication success rate

#### Alert Triggers
- Build failure > 2 consecutive times
- Test coverage drop > 5%
- Security vulnerability detection
- Package installation failure rate > 10%

## Security Considerations

### Secure Deployment Pipeline

#### Code Signing
```bash
# Sign packages
gpg --detach-sign --armor package.deb
gpg --detach-sign --armor package.rpm

# Verify signatures
gpg --verify package.deb.asc package.deb
```

#### Secret Management
```bash
# GitHub Secrets
GITHUB_TOKEN          # For releases
GPG_PRIVATE_KEY       # For signing
DOCKER_HUB_TOKEN      # For container registry

# Environment isolation
export DEPLOYMENT_ENV=staging
export GITHUB_REPOSITORY=user/repo
```

#### Supply Chain Security
- Dependency scanning with Trivy
- Container image scanning
- SBOM (Software Bill of Materials) generation
- Provenance attestation

## Troubleshooting

### Common Issues

#### Build Failures
```bash
# Debug build environment
./deploy.sh check

# Clean rebuild
make clean && make package

# Verbose build
VERBOSE=1 make package
```

#### Test Failures
```bash
# Run specific test
./simple_backup_test.sh

# Debug test environment
ls -la tests/fixtures/

# Check test dependencies
which bats shellcheck shfmt
```

#### Deployment Issues
```bash
# Check staging environment
docker ps
docker logs staging-container

# Verify package integrity
dpkg -I package.deb
rpm -qpi package.rpm
```

### Support Channels

- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions  
- **Security:** security@project.org
- **Documentation:** /docs/ directory

## Future Enhancements

### Planned Automation Features

#### Advanced Testing
- Hardware-in-the-loop testing
- Performance benchmarking
- Chaos engineering integration
- User acceptance testing automation

#### Enhanced Deployment
- Blue-green deployments
- Canary releases
- Automatic rollback triggers
- Multi-region deployment

#### Monitoring Integration
- Prometheus metrics
- Grafana dashboards
- Log aggregation
- Error tracking integration
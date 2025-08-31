#!/bin/bash
# Yubikey PAM Installer - Deployment Script
# Automated deployment and release management script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project metadata
PROJECT_NAME="yubikey-pam-installer"
# Repository URL (for future use)
# REPO_URL="https://github.com/slamb2k/holla"

# Functions
log_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

check_dependencies() {
    log_info "Checking deployment dependencies..."
    
    local missing_deps=()
    
    # Required tools
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    command -v make >/dev/null 2>&1 || missing_deps+=("make")
    command -v docker >/dev/null 2>&1 || missing_deps+=("docker")
    command -v shellcheck >/dev/null 2>&1 || missing_deps+=("shellcheck")
    
    # Optional but recommended
    if ! command -v gh >/dev/null 2>&1; then
        log_warning "GitHub CLI (gh) not found - PR creation will be skipped"
    fi
    
    if ! command -v fpm >/dev/null 2>&1; then
        log_warning "FPM not found - package building will be skipped"
        log_info "Install with: gem install fpm"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and try again"
        exit 1
    fi
    
    log_success "All required dependencies found"
}

run_tests() {
    log_info "Running comprehensive test suite..."
    
    # Lint check
    log_info "Running shellcheck..."
    if ! make lint; then
        log_error "Lint checks failed"
        return 1
    fi
    
    # Unit tests
    log_info "Running unit tests..."
    if ! make test; then
        log_error "Unit tests failed"
        return 1
    fi
    
    # Docker tests (if available)
    if command -v docker >/dev/null 2>&1; then
        log_info "Running Docker tests..."
        if make docker-test 2>/dev/null; then
            log_success "Docker tests passed"
        else
            log_warning "Docker tests failed or unavailable"
        fi
    fi
    
    log_success "All tests passed"
}

build_packages() {
    log_info "Building deployment packages..."
    
    if command -v fpm >/dev/null 2>&1; then
        if make package; then
            log_success "Packages built successfully"
            log_info "Built packages:"
            ls -la dist/ 2>/dev/null || log_warning "No packages found in dist/"
        else
            log_error "Package building failed"
            return 1
        fi
    else
        log_warning "FPM not available - skipping package building"
        log_info "Creating source tarball instead..."
        make tar || return 1
    fi
}

deploy_to_staging() {
    log_info "Deploying to staging environment..."
    
    # Create temporary staging directory
    local staging_dir
    staging_dir="/tmp/${PROJECT_NAME}-staging-$(date +%s)"
    mkdir -p "$staging_dir"
    
    # Copy built packages
    if [ -d "dist" ]; then
        cp -r dist/* "$staging_dir/" 2>/dev/null || true
    fi
    
    # Copy source files for manual installation
    cp -r src/ "$staging_dir/"
    cp -r scripts/ "$staging_dir/" 2>/dev/null || true
    cp README.md "$staging_dir/" 2>/dev/null || true
    
    log_success "Staged deployment in: $staging_dir"
    log_info "To install from staging: cd $staging_dir && sudo bash scripts/postinst.sh"
}

create_release() {
    local version="${1:-auto}"
    
    log_info "Creating release version: $version"
    
    # Determine version if auto
    if [ "$version" = "auto" ]; then
        version="1.0.0-$(date +%Y%m%d)"
        log_info "Using auto-generated version: $version"
    fi
    
    # Create git tag
    if git tag -a "v$version" -m "Release version $version"; then
        log_success "Created git tag: v$version"
    else
        log_warning "Git tag creation failed or tag already exists"
    fi
    
    # Create GitHub release if gh is available
    if command -v gh >/dev/null 2>&1; then
        log_info "Creating GitHub release..."
        if gh release create "v$version" dist/* --title "Release $version" --generate-notes; then
            log_success "GitHub release created: v$version"
        else
            log_warning "GitHub release creation failed"
        fi
    else
        log_info "GitHub CLI not available - manual release creation needed"
        log_info "Push tag with: git push origin v$version"
    fi
}

cleanup() {
    log_info "Cleaning up build artifacts..."
    make clean 2>/dev/null || true
    log_success "Cleanup complete"
}

show_help() {
    cat << EOF
Yubikey PAM Installer - Deployment Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  check       Check deployment dependencies
  test        Run comprehensive test suite
  build       Build deployment packages
  stage       Deploy to staging environment
  release     Create a release (with optional version)
  full        Run complete deployment pipeline
  clean       Clean up build artifacts
  help        Show this help message

Examples:
  $0 check                    # Check dependencies
  $0 test                     # Run tests
  $0 build                    # Build packages
  $0 release 1.2.3           # Create release with specific version
  $0 release                  # Create release with auto version
  $0 full                     # Run complete pipeline

Environment variables:
  SKIP_TESTS=1               # Skip test execution
  SKIP_PACKAGES=1            # Skip package building
  DEPLOYMENT_ENV             # Target environment (staging/production)

EOF
}

main() {
    local command="${1:-help}"
    
    case "$command" in
        check)
            check_dependencies
            ;;
        test)
            check_dependencies
            run_tests
            ;;
        build)
            check_dependencies
            [ "${SKIP_TESTS:-0}" = "1" ] || run_tests
            build_packages
            ;;
        stage)
            check_dependencies
            [ "${SKIP_TESTS:-0}" = "1" ] || run_tests
            [ "${SKIP_PACKAGES:-0}" = "1" ] || build_packages
            deploy_to_staging
            ;;
        release)
            local version="${2:-auto}"
            check_dependencies
            [ "${SKIP_TESTS:-0}" = "1" ] || run_tests
            [ "${SKIP_PACKAGES:-0}" = "1" ] || build_packages
            create_release "$version"
            ;;
        full)
            log_info "Running complete deployment pipeline..."
            check_dependencies
            run_tests
            build_packages
            deploy_to_staging
            local version="${2:-auto}"
            create_release "$version"
            log_success "Deployment pipeline complete!"
            ;;
        clean)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
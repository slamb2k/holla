# Yubikey PAM Installer - Makefile
# Build system for creating packages and managing the project

# Project metadata
NAME := yubikey-pam-installer
VERSION := 1.0.0
RELEASE := 1
ARCH := all

# Build information
BUILD_DATE := $(shell date +%Y%m%d)
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
FULL_VERSION := $(VERSION)-$(RELEASE)

# Package metadata
MAINTAINER := "slamb2k <slamb2k@github.com>"
DESCRIPTION := "Automated Yubikey U2F PAM configuration tool for Linux systems"
URL := "https://github.com/slamb2k/holla"
LICENSE := "MIT"

# Dependencies by package format
DEB_DEPENDS := --depends "libpam-u2f" --depends "bash (>= 5.0)"
RPM_DEPENDS := --depends "pam-u2f" --depends "bash >= 5.0"
ARCH_DEPENDS := --depends "pam-u2f"

# Directories
BUILD_DIR := build
PACKAGE_DIR := $(BUILD_DIR)/package
DIST_DIR := dist
MAN_DIR := man

# Source files
SRC_FILES := $(wildcard src/*.sh)
TEST_FILES := $(wildcard tests/*.bats)
DEMO_FILES := $(wildcard demo_*.sh)
SIMPLE_TEST_FILES := $(wildcard simple_*_test.sh)
DOC_FILES := $(wildcard docs/**/*.md)

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

# Phony targets
.PHONY: all help clean install uninstall test lint format check package deb rpm arch tar docker version
.PHONY: docker-build docker-test docker-clean docker-run dev-test dev-run dev-clean
.PHONY: ci-lint ci-test ci-build release-patch release-minor release-major

## help: Show this help message
help:
	@echo "$(YELLOW)Yubikey PAM Installer Build System$(NC)"
	@echo
	@echo "$(GREEN)Available targets:$(NC)"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'
	@echo
	@echo "$(GREEN)Project info:$(NC)"
	@echo "  Name: $(NAME)"
	@echo "  Version: $(FULL_VERSION)"
	@echo "  Git commit: $(GIT_COMMIT)"
	@echo

## all: Build all packages
all: clean check package

## version: Show version information
version:
	@echo "$(NAME) $(FULL_VERSION)"
	@echo "Build date: $(BUILD_DATE)"
	@echo "Git commit: $(GIT_COMMIT)"

## clean: Remove build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	rm -rf $(BUILD_DIR) $(DIST_DIR)
	@echo "$(GREEN)✓ Clean complete$(NC)"

## prepare: Create build directories and copy files
prepare: clean
	@echo "$(YELLOW)Preparing build environment...$(NC)"
	
	# Create directories
	mkdir -p $(PACKAGE_DIR)/usr/local/bin
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/src
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/tests
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/docs
	mkdir -p $(PACKAGE_DIR)/usr/share/doc/$(NAME)
	mkdir -p $(PACKAGE_DIR)/DEBIAN
	mkdir -p $(DIST_DIR)
	
	# Copy source files
	cp $(SRC_FILES) $(PACKAGE_DIR)/usr/share/$(NAME)/src/
	cp $(TEST_FILES) $(PACKAGE_DIR)/usr/share/$(NAME)/tests/ 2>/dev/null || true
	cp $(DEMO_FILES) $(PACKAGE_DIR)/usr/share/$(NAME)/ 2>/dev/null || true
	cp run_tests.sh $(PACKAGE_DIR)/usr/share/$(NAME)/ 2>/dev/null || true
	
	# Copy documentation
	cp README.md CLAUDE.md $(PACKAGE_DIR)/usr/share/doc/$(NAME)/ 2>/dev/null || true
	cp -r docs/* $(PACKAGE_DIR)/usr/share/$(NAME)/docs/ 2>/dev/null || true
	
	# Copy scripts
	cp scripts/* $(PACKAGE_DIR)/usr/share/$(NAME)/scripts/ 2>/dev/null || mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/scripts
	
	# Make scripts executable
	chmod +x $(PACKAGE_DIR)/usr/share/$(NAME)/src/*.sh
	chmod +x $(PACKAGE_DIR)/usr/share/$(NAME)/*.sh 2>/dev/null || true
	
	@echo "$(GREEN)✓ Prepare complete$(NC)"

## lint: Run shellcheck on all shell scripts
lint:
	@echo "$(YELLOW)Running shellcheck...$(NC)"
	shellcheck $(SRC_FILES) $(DEMO_FILES) $(SIMPLE_TEST_FILES)
	@echo "$(GREEN)✓ Lint passed$(NC)"

## format: Format shell scripts with shfmt
format:
	@echo "$(YELLOW)Formatting shell scripts...$(NC)"
	shfmt -i 2 -w $(SRC_FILES) $(DEMO_FILES) $(SIMPLE_TEST_FILES)
	@echo "$(GREEN)✓ Format complete$(NC)"

## test: Run test suites
test:
	@echo "$(YELLOW)Running tests...$(NC)"
	for test in $(SIMPLE_TEST_FILES); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
	done
	@echo "$(GREEN)✓ All tests passed$(NC)"

## check: Run lint and test
check: lint test
	@echo "$(GREEN)✓ All checks passed$(NC)"

## install: Install system-wide (requires sudo)
install: check prepare
	@echo "$(YELLOW)Installing system-wide...$(NC)"
	
	# Create system directories
	sudo mkdir -p /usr/local/bin
	sudo mkdir -p /usr/share/$(NAME)
	
	# Copy files
	sudo cp -r $(PACKAGE_DIR)/usr/share/$(NAME)/* /usr/share/$(NAME)/
	sudo cp scripts/postinst.sh /usr/share/$(NAME)/install.sh 2>/dev/null || echo "No postinst script"
	sudo cp scripts/prerm.sh /usr/share/$(NAME)/uninstall.sh 2>/dev/null || echo "No prerm script"
	
	# Make executable
	sudo chmod +x /usr/share/$(NAME)/src/*.sh
	sudo chmod +x /usr/share/$(NAME)/*.sh 2>/dev/null || true
	
	@echo "$(GREEN)✓ Installation complete$(NC)"
	@echo "Run: /usr/share/$(NAME)/install.sh to configure PAM"

## uninstall: Remove system installation (requires sudo)
uninstall:
	@echo "$(YELLOW)Uninstalling...$(NC)"
	sudo /usr/share/$(NAME)/uninstall.sh 2>/dev/null || echo "Uninstall script not found"
	sudo rm -rf /usr/share/$(NAME)
	@echo "$(GREEN)✓ Uninstall complete$(NC)"

## package: Build all package formats
package: prepare deb rpm arch tar
	@echo "$(GREEN)✓ All packages built in $(DIST_DIR)/$(NC)"

## deb: Build Debian package
deb: prepare
	@echo "$(YELLOW)Building Debian package...$(NC)"
	
	# Check if fpm exists
	@which fpm > /dev/null || (echo "$(RED)Error: fpm not found. Install with: gem install fpm$(NC)" && exit 1)
	
	# Create Debian control files
	echo "#!/bin/bash" > $(PACKAGE_DIR)/DEBIAN/postinst
	cat scripts/postinst.sh >> $(PACKAGE_DIR)/DEBIAN/postinst 2>/dev/null || echo "echo 'Post-install complete'"  >> $(PACKAGE_DIR)/DEBIAN/postinst
	chmod 755 $(PACKAGE_DIR)/DEBIAN/postinst
	
	echo "#!/bin/bash" > $(PACKAGE_DIR)/DEBIAN/prerm
	cat scripts/prerm.sh >> $(PACKAGE_DIR)/DEBIAN/prerm 2>/dev/null || echo "echo 'Pre-remove complete'" >> $(PACKAGE_DIR)/DEBIAN/prerm
	chmod 755 $(PACKAGE_DIR)/DEBIAN/prerm
	
	echo "#!/bin/bash" > $(PACKAGE_DIR)/DEBIAN/postrm
	cat scripts/postrm.sh >> $(PACKAGE_DIR)/DEBIAN/postrm 2>/dev/null || echo "echo 'Post-remove complete'" >> $(PACKAGE_DIR)/DEBIAN/postrm
	chmod 755 $(PACKAGE_DIR)/DEBIAN/postrm
	
	# Build package
	fpm -s dir -t deb \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a $(ARCH) \
		-m $(MAINTAINER) \
		--description $(DESCRIPTION) \
		--url $(URL) \
		--license $(LICENSE) \
		$(DEB_DEPENDS) \
		--deb-compression xz \
		--config-files /usr/share/$(NAME) \
		-p $(DIST_DIR)/$(NAME)_$(FULL_VERSION)_$(ARCH).deb \
		-C $(PACKAGE_DIR) \
		.
	
	@echo "$(GREEN)✓ Debian package: $(DIST_DIR)/$(NAME)_$(FULL_VERSION)_$(ARCH).deb$(NC)"

## rpm: Build RPM package
rpm: prepare
	@echo "$(YELLOW)Building RPM package...$(NC)"
	
	# Check if fpm exists
	@which fpm > /dev/null || (echo "$(RED)Error: fpm not found. Install with: gem install fpm$(NC)" && exit 1)
	
	fpm -s dir -t rpm \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a $(ARCH) \
		-m $(MAINTAINER) \
		--description $(DESCRIPTION) \
		--url $(URL) \
		--license $(LICENSE) \
		$(RPM_DEPENDS) \
		--rpm-compression xz \
		--config-files /usr/share/$(NAME) \
		-p $(DIST_DIR)/$(NAME)-$(FULL_VERSION).$(ARCH).rpm \
		-C $(PACKAGE_DIR) \
		.
	
	@echo "$(GREEN)✓ RPM package: $(DIST_DIR)/$(NAME)-$(FULL_VERSION).$(ARCH).rpm$(NC)"

## arch: Build Arch package
arch: prepare
	@echo "$(YELLOW)Building Arch package...$(NC)"
	
	# Check if fpm exists
	@which fpm > /dev/null || (echo "$(RED)Error: fpm not found. Install with: gem install fpm$(NC)" && exit 1)
	
	fpm -s dir -t pacman \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a $(ARCH) \
		-m $(MAINTAINER) \
		--description $(DESCRIPTION) \
		--url $(URL) \
		--license $(LICENSE) \
		$(ARCH_DEPENDS) \
		--config-files /usr/share/$(NAME) \
		-p $(DIST_DIR)/$(NAME)-$(FULL_VERSION)-$(ARCH).pkg.tar.xz \
		-C $(PACKAGE_DIR) \
		.
	
	@echo "$(GREEN)✓ Arch package: $(DIST_DIR)/$(NAME)-$(FULL_VERSION)-$(ARCH).pkg.tar.xz$(NC)"

## tar: Build tarball
tar: prepare
	@echo "$(YELLOW)Building tarball...$(NC)"
	
	tar -czf $(DIST_DIR)/$(NAME)-$(FULL_VERSION).tar.gz \
		-C $(PACKAGE_DIR) \
		--transform 's,^\.,$(NAME)-$(FULL_VERSION),' \
		.
	
	@echo "$(GREEN)✓ Tarball: $(DIST_DIR)/$(NAME)-$(FULL_VERSION).tar.gz$(NC)"

## docker-build: Build Docker test image
docker-build:
	@echo "$(YELLOW)Building Docker test image...$(NC)"
	docker build -f Dockerfile.test -t $(NAME)-test:$(VERSION) -t $(NAME)-test:latest .
	@echo "$(GREEN)✓ Docker image built: $(NAME)-test:$(VERSION)$(NC)"

## docker-test: Run tests in Docker container
docker-test: docker-build
	@echo "$(YELLOW)Running tests in Docker...$(NC)"
	docker run --rm $(NAME)-test:latest
	@echo "$(GREEN)✓ Docker tests completed$(NC)"

## docker-run: Run interactive shell in Docker container
docker-run: docker-build
	@echo "$(YELLOW)Starting interactive Docker container...$(NC)"
	docker run --rm -it $(NAME)-test:latest bash

## docker-compose-test: Run full test matrix with Docker Compose
docker-compose-test:
	@echo "$(YELLOW)Running test matrix with Docker Compose...$(NC)"
	docker-compose up --build ubuntu20-test ubuntu24-test
	docker-compose down
	@echo "$(GREEN)✓ Docker Compose tests completed$(NC)"

## docker-clean: Clean Docker images
docker-clean:
	@echo "$(YELLOW)Cleaning Docker images...$(NC)"
	docker rmi $(NAME)-test:latest $(NAME)-test:$(VERSION) 2>/dev/null || true
	docker-compose down --rmi all 2>/dev/null || true
	@echo "$(GREEN)✓ Docker cleanup complete$(NC)"

# Development shortcuts
## dev-test: Quick test during development
dev-test:
	@./simple_test.sh && ./simple_backup_test.sh && ./simple_registration_test.sh

## dev-run: Run demo scripts
dev-run:
	@./demo_parser.sh
	@./demo_backup.sh
	@./demo_registration.sh

## dev-clean: Clean and rebuild
dev-clean: clean package

# CI/CD helpers
ci-lint:
	@shellcheck -S error $(SRC_FILES)

ci-test:
	@for test in $(SIMPLE_TEST_FILES); do ./$$test || exit 1; done

ci-build: check package
	@echo "Build artifacts in $(DIST_DIR)/"

# Release management
release-patch:
	@echo "Current version: $(VERSION)"
	@echo "Creating patch release..."
	# Would increment patch version and create git tag

release-minor:
	@echo "Current version: $(VERSION)"
	@echo "Creating minor release..."
	# Would increment minor version and create git tag

release-major:
	@echo "Current version: $(VERSION)"
	@echo "Creating major release..."
	# Would increment major version and create git tag
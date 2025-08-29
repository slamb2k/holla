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

## help: Show this help message
help:
	@echo "$(GREEN)Yubikey PAM Installer - Build System$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "$(YELLOW)Package building:$(NC)"
	@echo "  make package    - Build all package formats"
	@echo "  make deb       - Build Debian package"
	@echo "  make rpm       - Build RPM package"
	@echo "  make arch      - Build Arch Linux package"
	@echo "  make tar       - Build universal tarball"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  make test      - Run all tests"
	@echo "  make lint      - Run shellcheck"
	@echo "  make format    - Format shell scripts"
	@echo "  make check     - Run all checks"
	@echo ""
	@echo "Current version: $(GREEN)$(VERSION)$(NC)"

## clean: Remove build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	rm -rf $(BUILD_DIR) $(DIST_DIR)
	rm -f *.deb *.rpm *.pkg.tar.xz *.tar.gz
	@echo "$(GREEN)✓ Clean complete$(NC)"

## version: Display version information
version:
	@echo "Version: $(VERSION)"
	@echo "Release: $(RELEASE)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"

# Create build directories
$(BUILD_DIR) $(DIST_DIR) $(PACKAGE_DIR):
	mkdir -p $@

# Prepare package structure
prepare: $(PACKAGE_DIR)
	@echo "$(YELLOW)Preparing package structure...$(NC)"
	
	# Create directory structure
	mkdir -p $(PACKAGE_DIR)/usr/local/bin
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/src
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/docs
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/tests
	mkdir -p $(PACKAGE_DIR)/etc/$(NAME)
	mkdir -p $(PACKAGE_DIR)/usr/share/man/man1
	
	# Copy main scripts
	cp $(SRC_FILES) $(PACKAGE_DIR)/usr/share/$(NAME)/src/
	chmod 755 $(PACKAGE_DIR)/usr/share/$(NAME)/src/*.sh
	
	# Copy demo and test scripts
	cp $(DEMO_FILES) $(SIMPLE_TEST_FILES) $(PACKAGE_DIR)/usr/share/$(NAME)/
	chmod 755 $(PACKAGE_DIR)/usr/share/$(NAME)/*.sh
	
	# Copy tests
	cp -r tests/* $(PACKAGE_DIR)/usr/share/$(NAME)/tests/ 2>/dev/null || true
	
	# Copy documentation
	cp -r docs/* $(PACKAGE_DIR)/usr/share/$(NAME)/docs/ 2>/dev/null || true
	cp README.md CLAUDE.md $(PACKAGE_DIR)/usr/share/$(NAME)/docs/ 2>/dev/null || true
	
	# Create wrapper scripts
	echo '#!/bin/bash' > $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-install
	echo 'exec /usr/share/$(NAME)/src/install.sh "$$@"' >> $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-install
	chmod 755 $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-install
	
	echo '#!/bin/bash' > $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-register
	echo 'exec /usr/share/$(NAME)/src/u2f_registration.sh "$$@"' >> $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-register
	chmod 755 $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-register
	
	# Create version file
	echo "$(VERSION)" > $(PACKAGE_DIR)/usr/share/$(NAME)/VERSION
	
	@echo "$(GREEN)✓ Package structure prepared$(NC)"

## test: Run all tests
test:
	@echo "$(YELLOW)Running tests...$(NC)"
	@for test in $(SIMPLE_TEST_FILES); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
	done
	@echo "$(GREEN)✓ All tests passed$(NC)"

## lint: Run shellcheck on all shell scripts
lint:
	@echo "$(YELLOW)Running shellcheck...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S warning $(SRC_FILES) $(DEMO_FILES) $(SIMPLE_TEST_FILES) || exit 1; \
		echo "$(GREEN)✓ Shellcheck passed$(NC)"; \
	else \
		echo "$(RED)✗ shellcheck not installed$(NC)"; \
		exit 1; \
	fi

## format: Format shell scripts with shfmt
format:
	@echo "$(YELLOW)Formatting shell scripts...$(NC)"
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -i 2 -w $(SRC_FILES) $(DEMO_FILES) $(SIMPLE_TEST_FILES); \
		echo "$(GREEN)✓ Formatting complete$(NC)"; \
	else \
		echo "$(RED)✗ shfmt not installed$(NC)"; \
		exit 1; \
	fi

## check: Run all quality checks
check: lint test
	@echo "$(GREEN)✓ All checks passed$(NC)"

## install: Install locally (requires sudo)
install: prepare
	@echo "$(YELLOW)Installing locally...$(NC)"
	sudo cp -r $(PACKAGE_DIR)/* /
	@echo "$(GREEN)✓ Installation complete$(NC)"
	@echo "Run 'yubikey-pam-register' to register your Yubikey"

## uninstall: Uninstall from system (requires sudo)
uninstall:
	@echo "$(YELLOW)Uninstalling...$(NC)"
	sudo rm -rf /usr/share/$(NAME)
	sudo rm -f /usr/local/bin/yubikey-pam-*
	@echo "$(GREEN)✓ Uninstallation complete$(NC)"

## deb: Build Debian package
deb: prepare $(DIST_DIR)
	@echo "$(YELLOW)Building Debian package...$(NC)"
	@if ! command -v fpm >/dev/null 2>&1; then \
		echo "$(RED)✗ FPM not installed. Run: gem install fpm$(NC)"; \
		exit 1; \
	fi
	
	fpm -s dir -t deb \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a $(ARCH) \
		-m "$(MAINTAINER)" \
		--description "$(DESCRIPTION)" \
		--url "$(URL)" \
		--license "$(LICENSE)" \
		$(DEB_DEPENDS) \
		--after-install scripts/postinst.sh \
		--before-remove scripts/prerm.sh \
		--after-remove scripts/postrm.sh \
		--deb-no-default-config-files \
		-C $(PACKAGE_DIR) \
		--package $(DIST_DIR)/ \
		.
	
	@echo "$(GREEN)✓ Debian package built: $(DIST_DIR)/$(NAME)_$(VERSION)-$(RELEASE)_$(ARCH).deb$(NC)"

## rpm: Build RPM package
rpm: prepare $(DIST_DIR)
	@echo "$(YELLOW)Building RPM package...$(NC)"
	@if ! command -v fpm >/dev/null 2>&1; then \
		echo "$(RED)✗ FPM not installed. Run: gem install fpm$(NC)"; \
		exit 1; \
	fi
	
	fpm -s dir -t rpm \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a noarch \
		-m "$(MAINTAINER)" \
		--description "$(DESCRIPTION)" \
		--url "$(URL)" \
		--license "$(LICENSE)" \
		$(RPM_DEPENDS) \
		--after-install scripts/postinst.sh \
		--before-remove scripts/prerm.sh \
		--after-remove scripts/postrm.sh \
		-C $(PACKAGE_DIR) \
		--package $(DIST_DIR)/ \
		.
	
	@echo "$(GREEN)✓ RPM package built: $(DIST_DIR)/$(NAME)-$(VERSION)-$(RELEASE).noarch.rpm$(NC)"

## arch: Build Arch Linux package
arch: prepare $(DIST_DIR)
	@echo "$(YELLOW)Building Arch Linux package...$(NC)"
	@if ! command -v fpm >/dev/null 2>&1; then \
		echo "$(RED)✗ FPM not installed. Run: gem install fpm$(NC)"; \
		exit 1; \
	fi
	
	fpm -s dir -t pacman \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a any \
		-m "$(MAINTAINER)" \
		--description "$(DESCRIPTION)" \
		--url "$(URL)" \
		--license "$(LICENSE)" \
		$(ARCH_DEPENDS) \
		-C $(PACKAGE_DIR) \
		--package $(DIST_DIR)/ \
		.
	
	@echo "$(GREEN)✓ Arch package built: $(DIST_DIR)/$(NAME)-$(VERSION)-$(RELEASE)-any.pkg.tar.xz$(NC)"

## tar: Build universal tarball
tar: prepare $(DIST_DIR)
	@echo "$(YELLOW)Building universal tarball...$(NC)"
	cd $(PACKAGE_DIR) && tar czf ../../$(DIST_DIR)/$(NAME)-$(VERSION).tar.gz *
	@echo "$(GREEN)✓ Tarball built: $(DIST_DIR)/$(NAME)-$(VERSION).tar.gz$(NC)"

## package: Build all package formats
package: deb rpm arch tar
	@echo "$(GREEN)✓ All packages built successfully$(NC)"
	@ls -lh $(DIST_DIR)/

## docker: Build Docker image
docker: prepare
	@echo "$(YELLOW)Building Docker image...$(NC)"
	
	# Create Dockerfile
	echo "FROM ubuntu:22.04" > $(BUILD_DIR)/Dockerfile
	echo "RUN apt-get update && apt-get install -y libpam-u2f pamu2fcfg bash sudo && rm -rf /var/lib/apt/lists/*" >> $(BUILD_DIR)/Dockerfile
	echo "COPY package/usr/share/$(NAME) /usr/share/$(NAME)" >> $(BUILD_DIR)/Dockerfile
	echo "COPY package/usr/local/bin/* /usr/local/bin/" >> $(BUILD_DIR)/Dockerfile
	echo "RUN chmod +x /usr/share/$(NAME)/src/*.sh /usr/local/bin/*" >> $(BUILD_DIR)/Dockerfile
	echo "WORKDIR /usr/share/$(NAME)" >> $(BUILD_DIR)/Dockerfile
	echo "ENTRYPOINT [\"/bin/bash\"]" >> $(BUILD_DIR)/Dockerfile
	
	# Build image
	docker build -t $(NAME):$(VERSION) -t $(NAME):latest $(BUILD_DIR)
	
	@echo "$(GREEN)✓ Docker image built: $(NAME):$(VERSION)$(NC)"

# Development shortcuts
.PHONY: dev-test dev-run dev-clean

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
.PHONY: ci-lint ci-test ci-build

ci-lint:
	@shellcheck -S error $(SRC_FILES)

ci-test:
	@for test in $(SIMPLE_TEST_FILES); do ./$$test || exit 1; done

ci-build: check package
	@echo "Build artifacts in $(DIST_DIR)/"

# Release management
.PHONY: release-patch release-minor release-major

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
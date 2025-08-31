# Packaging Guide

How to create distributable packages for the Yubikey PAM Installer.

## Package Formats

### Supported Formats

| Format | Distribution | Tool | Extension |
|--------|-------------|------|-----------|
| DEB | Debian/Ubuntu | dpkg | .deb |
| RPM | Fedora/RHEL | rpm | .rpm |
| PKG | Arch Linux | pacman | .pkg.tar.xz |
| TAR | Universal | tar | .tar.gz |

## Prerequisites

### Install FPM (Effing Package Management)

```bash
# Install Ruby first
sudo apt-get install ruby ruby-dev build-essential

# Install FPM
sudo gem install fpm

# Verify installation
fpm --version
```

## Package Structure

```
yubikey-pam-installer/
├── usr/
│   ├── local/
│   │   └── bin/
│   │   ├── yubikey-pam-install
│   │   ├── yubikey-pam-register
│   │   └── yubikey-pam-uninstall
│   └── share/
│   ├── yubikey-pam-installer/
│   │   ├── src/
│   │   └── docs/
│   └── man/
│   └── man1/
│   └── yubikey-pam-installer.1
├── etc/
│   └── yubikey-pam/
│   └── config.default
└── DEBIAN/ (or RPM spec)
├── control
├── postinst
├── prerm
└── postrm
```

## Building Packages

### Makefile Configuration

```makefile
# Makefile
NAME = yubikey-pam-installer
VERSION = 1.0.0
RELEASE = 1
ARCH = all

# Package metadata
MAINTAINER = "Your Name <email@example.com>"
DESCRIPTION = "Yubikey U2F PAM Configuration Tool"
URL = "https://github.com/org/yubikey-pam-installer"
LICENSE = "MIT"

# Dependencies by distribution
DEB_DEPENDS = "libpam-u2f, pamu2fcfg, bash (>= 5.0)"
RPM_DEPENDS = "pam-u2f, pamu2fcfg, bash >= 5.0"

# Build directories
BUILD_DIR = build
PACKAGE_DIR = $(BUILD_DIR)/package

.PHONY: all clean package deb rpm arch

all: package

clean:
	rm -rf $(BUILD_DIR)

prepare:
	mkdir -p $(PACKAGE_DIR)/usr/local/bin
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/src
	mkdir -p $(PACKAGE_DIR)/usr/share/$(NAME)/docs
	mkdir -p $(PACKAGE_DIR)/etc/yubikey-pam
	
	# Copy executables
	cp install.sh $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-install
	cp uninstall.sh $(PACKAGE_DIR)/usr/local/bin/yubikey-pam-uninstall
	
	# Copy source files
	cp -r src/* $(PACKAGE_DIR)/usr/share/$(NAME)/src/
	
	# Copy documentation
	cp -r docs/* $(PACKAGE_DIR)/usr/share/$(NAME)/docs/
	
	# Set permissions
	chmod 755 $(PACKAGE_DIR)/usr/local/bin/*
	chmod 644 $(PACKAGE_DIR)/usr/share/$(NAME)/src/*
	chmod 755 $(PACKAGE_DIR)/usr/share/$(NAME)/src/*.sh

deb: prepare
	fpm -s dir -t deb \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a $(ARCH) \
		-m "$(MAINTAINER)" \
		--description "$(DESCRIPTION)" \
		--url "$(URL)" \
		--license "$(LICENSE)" \
		--depends $(DEB_DEPENDS) \
		--after-install scripts/postinst.sh \
		--before-remove scripts/prerm.sh \
		--after-remove scripts/postrm.sh \
		-C $(PACKAGE_DIR) \
		.

rpm: prepare
	fpm -s dir -t rpm \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a $(ARCH) \
		-m "$(MAINTAINER)" \
		--description "$(DESCRIPTION)" \
		--url "$(URL)" \
		--license "$(LICENSE)" \
		--depends $(RPM_DEPENDS) \
		--after-install scripts/postinst.sh \
		--before-remove scripts/prerm.sh \
		--after-remove scripts/postrm.sh \
		-C $(PACKAGE_DIR) \
		.

arch: prepare
	fpm -s dir -t pacman \
		-n $(NAME) \
		-v $(VERSION) \
		--iteration $(RELEASE) \
		-a $(ARCH) \
		-m "$(MAINTAINER)" \
		--description "$(DESCRIPTION)" \
		--url "$(URL)" \
		--license "$(LICENSE)" \
		--depends pam-u2f \
		-C $(PACKAGE_DIR) \
		.

package: deb rpm arch
```

## Package Scripts

### Post-Installation Script

```bash
#!/bin/bash
# scripts/postinst.sh

set -e

# Create necessary directories
mkdir -p /var/log/yubikey-pam
mkdir -p /etc/yubikey-pam/backup

# Set permissions
chmod 700 /etc/yubikey-pam/backup

# Create symlinks for convenience
ln -sf /usr/share/yubikey-pam-installer/src/u2f_registration.sh \
   /usr/local/bin/yubikey-register

# Check for required dependencies
if ! command -v pamu2fcfg >/dev/null 2>&1; then
echo "Warning: pamu2fcfg not found. Please install libpam-u2f"
fi

echo "Yubikey PAM Installer successfully installed!"
echo "Run 'yubikey-pam-install' to configure PAM"
echo "Run 'yubikey-register' to register your Yubikey"

exit 0
```

### Pre-Removal Script

```bash
#!/bin/bash
# scripts/prerm.sh

set -e

# Check if PAM is configured with Yubikey
if grep -q "pam_u2f.so" /etc/pam.d/sudo 2>/dev/null; then
echo "Warning: Yubikey PAM configuration detected"
echo "Run 'yubikey-pam-uninstall' before removing package"
read -p "Continue anyway? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
exit 1
fi
fi

exit 0
```

### Post-Removal Script

```bash
#!/bin/bash
# scripts/postrm.sh

set -e

# Clean up logs (optional)
if [ "$1" = "purge" ]; then
rm -rf /var/log/yubikey-pam
rm -rf /etc/yubikey-pam
fi

# Remove symlinks
rm -f /usr/local/bin/yubikey-register

echo "Yubikey PAM Installer removed"

exit 0
```

## Building Process

### Step-by-Step Build

```bash
# 1. Clean previous builds
make clean

# 2. Build all packages
make package

# 3. Build specific format
make deb# Debian/Ubuntu
make rpm# Fedora/RHEL
make arch   # Arch Linux

# 4. Check created packages
ls -la *.deb *.rpm *.pkg.tar.xz
```

### Version Management

```bash
# Update version in Makefile
VERSION = 1.0.1

# Tag release in git
git tag -a v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1
```

## Package Testing

### Local Installation Test

```bash
# Debian/Ubuntu
sudo dpkg -i yubikey-pam-installer_1.0.0-1_all.deb

# Fedora/RHEL
sudo rpm -ivh yubikey-pam-installer-1.0.0-1.noarch.rpm

# Arch
sudo pacman -U yubikey-pam-installer-1.0.0-1-any.pkg.tar.xz
```

### Dependency Check

```bash
# Debian/Ubuntu
dpkg -I yubikey-pam-installer_1.0.0-1_all.deb

# RPM
rpm -qpR yubikey-pam-installer-1.0.0-1.noarch.rpm

# Arch
pacman -Qpi yubikey-pam-installer-1.0.0-1-any.pkg.tar.xz
```

### Content Verification

```bash
# List package contents
dpkg -c yubikey-pam-installer_1.0.0-1_all.deb
rpm -qpl yubikey-pam-installer-1.0.0-1.noarch.rpm
tar -tvf yubikey-pam-installer-1.0.0-1-any.pkg.tar.xz
```

## Distribution

### Repository Setup

#### APT Repository (Debian/Ubuntu)

```bash
# Create repository structure
mkdir -p repo/dists/stable/main/binary-all
mkdir -p repo/pool/main/y/yubikey-pam-installer

# Copy package
cp *.deb repo/pool/main/y/yubikey-pam-installer/

# Generate Packages file
cd repo
dpkg-scanpackages pool/ > dists/stable/main/binary-all/Packages
gzip -k dists/stable/main/binary-all/Packages
```

#### YUM Repository (Fedora/RHEL)

```bash
# Create repository structure
mkdir -p repo/packages

# Copy packages
cp *.rpm repo/packages/

# Create repository metadata
createrepo repo/
```

### GitHub Releases

```bash
# Create release with gh CLI
gh release create v1.0.0 \
  --title "Release v1.0.0" \
  --notes "Release notes here" \
  yubikey-pam-installer_1.0.0-1_all.deb \
  yubikey-pam-installer-1.0.0-1.noarch.rpm \
  yubikey-pam-installer-1.0.0-1-any.pkg.tar.xz
```

## Package Metadata

### Debian Control File

```
Package: yubikey-pam-installer
Version: 1.0.0-1
Section: admin
Priority: optional
Architecture: all
Depends: libpam-u2f, pamu2fcfg, bash (>= 5.0)
Maintainer: Your Name <email@example.com>
Description: Yubikey U2F PAM Configuration Tool
 Automated tool for configuring Linux PAM to use Yubikey
 U2F tokens for authentication. Provides safe configuration
 with backup and rollback capabilities.
Homepage: https://github.com/org/yubikey-pam-installer
```

### RPM Spec File

```spec
Name:   yubikey-pam-installer
Version:1.0.0
Release:1%{?dist}
Summary:Yubikey U2F PAM Configuration Tool

License:MIT
URL:https://github.com/org/yubikey-pam-installer
Source0:%{name}-%{version}.tar.gz

Requires:   pam-u2f
Requires:   pamu2fcfg
Requires:   bash >= 5.0

BuildArch:  noarch

%description
Automated tool for configuring Linux PAM to use Yubikey
U2F tokens for authentication. Provides safe configuration
with backup and rollback capabilities.

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/%{name}
cp -r * %{buildroot}%{_datadir}/%{name}/

%files
%{_bindir}/*
%{_datadir}/%{name}

%changelog
* Thu Aug 29 2024 Your Name <email@example.com> - 1.0.0-1
- Initial release
```

## Continuous Integration

### GitHub Actions Packaging

```yaml
name: Build Packages

on:
  push:
tags:
  - 'v*'

jobs:
  build:
runs-on: ubuntu-latest
steps:
- uses: actions/checkout@v2
- name: Install FPM
  run: |
sudo apt-get update
sudo apt-get install -y ruby ruby-dev build-essential
sudo gem install fpm
- name: Build packages
  run: make package
- name: Upload artifacts
  uses: actions/upload-artifact@v2
  with:
name: packages
path: |
  *.deb
  *.rpm
  *.pkg.tar.xz
- name: Create Release
  if: startsWith(github.ref, 'refs/tags/')
  uses: softprops/action-gh-release@v1
  with:
files: |
  *.deb
  *.rpm
  *.pkg.tar.xz
```

## Next Steps

- [System Integration](./system-integration.md) - Integrating with system services
- [Configuration Management](./configuration.md) - Managing at scale
- [Rollback Procedures](./rollback.md) - Emergency recovery
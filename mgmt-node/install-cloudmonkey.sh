#!/bin/bash
# CloudMonkey Installation Script
# Downloads and installs CloudMonkey binary from GitHub releases
#
# Usage: sudo ./install-cloudmonkey.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLOUDMONKEY_VERSION="6.5.0"
GITHUB_RELEASE_URL="https://github.com/apache/cloudstack-cloudmonkey/releases/download"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="cmk"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

detect_architecture() {
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$os" in
        linux)
            case "$arch" in
                x86_64|amd64)
                    echo "cmk.linux.x86-64"
                    ;;
                i386|i686|x86)
                    echo "cmk.linux.x86"
                    ;;
                aarch64|arm64)
                    echo "cmk.linux.arm64"
                    ;;
                armv7l|armv6l)
                    echo "cmk.linux.arm32"
                    ;;
                *)
                    log_error "Unsupported architecture: $arch"
                    exit 1
                    ;;
            esac
            ;;
        darwin)
            case "$arch" in
                arm64)
                    echo "cmk.darwin.arm64"
                    ;;
                x86_64|amd64)
                    echo "cmk.darwin.x86-64"
                    ;;
                *)
                    log_error "Unsupported architecture: $arch"
                    exit 1
                    ;;
            esac
            ;;
        *)
            log_error "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

check_existing() {
    if command -v cmk &> /dev/null; then
        log_info "CloudMonkey is already installed"
        cmk --version
        echo ""
        read -p "Reinstall? (yes/no): " reinstall
        if [[ "$reinstall" != "yes" ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
}

download_cloudmonkey() {
    local binary_file=$1
    local download_url="${GITHUB_RELEASE_URL}/${CLOUDMONKEY_VERSION}/${binary_file}"
    local temp_file="/tmp/${binary_file}"
    
    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "$temp_file" "$download_url"
    elif command -v curl &> /dev/null; then
        curl -L -o "$temp_file" "$download_url"
    else
        log_error "Neither wget nor curl is installed!"
        log_error "Please install wget or curl first"
        exit 1
    fi
    
    if [[ ! -f "$temp_file" ]]; then
        log_error "Download failed!"
        exit 1
    fi
    
    echo "$temp_file"
}

install_cloudmonkey() {
    local temp_file=$1
    local install_path="${INSTALL_DIR}/${BINARY_NAME}"
    
    log_info "Installing CloudMonkey to ${install_path}..."
    
    # Make binary executable
    chmod +x "$temp_file"
    
    # Move to install directory
    mv "$temp_file" "$install_path"
    
    log_info "CloudMonkey binary installed"
}

verify_installation() {
    log_info "Verifying installation..."
    
    if command -v cmk &> /dev/null; then
        log_info "CloudMonkey installed successfully!"
        echo ""
        cmk --version
        return 0
    else
        log_error "CloudMonkey installation failed!"
        log_error "Binary not found in PATH"
        return 1
    fi
}

print_usage() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          CloudMonkey Installation Complete!               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Quick Start:"
    echo "  1. Configure CloudMonkey:"
    echo "     cmk set url http://YOUR-MGMT-SERVER:8080/client/api"
    echo "     cmk set apikey YOUR-API-KEY"
    echo "     cmk set secretkey YOUR-SECRET-KEY"
    echo "     cmk set display table"
    echo ""
    echo "  2. Sync APIs (optional but recommended):"
    echo "     cmk sync"
    echo ""
    echo "  3. Test connection:"
    echo "     cmk list zones"
    echo ""
    echo "Basic Commands:"
    echo "  cmk help                    - Show help"
    echo "  cmk list zones              - List zones"
    echo "  cmk list hosts              - List hosts"
    echo "  cmk list virtualmachines    - List VMs"
    echo ""
    echo "Get API Credentials:"
    echo "  1. Login to CloudStack UI as admin"
    echo "  2. Go to: Accounts → admin → View Users"
    echo "  3. Click on 'admin' user"
    echo "  4. Go to 'Keys' tab"
    echo "  5. Click 'Generate Keys' or use existing keys"
    echo ""
    echo "Documentation:"
    echo "  https://github.com/apache/cloudstack-cloudmonkey/wiki"
    echo ""
}

print_checksums() {
    log_info "CloudMonkey v${CLOUDMONKEY_VERSION} SHA-256 checksums:"
    echo ""
    echo "Linux x86-64:  0861cb684acce4b92caea65a9d2b048a96d3599b05e7772c87743884bf1c706c"
    echo "Linux x86:     73f3f4cf9f419c1fcd3266cf3f1ddeb7b9063de9b6688296fbdba3bb5896dab1"
    echo "Linux ARM64:   7885515c33630e45d94ade05847fd0110a9972b7f2650799d12f23432cee7cef"
    echo "Linux ARM32:   0ac271fe57a4c8e24d8e99b95e1ff1ab73918c492892da9905459d60b3df0738"
    echo "macOS ARM64:   056a03bbed99050aceab5fe32489c9ec4bcb143c6accebfb49f3ec34bd974998"
    echo "macOS x86-64:  11cb907ec7331e95169c8d75c3e3f70c92268f9b42036ce1df435791ddeb3847"
    echo ""
}

main() {
    log_info "CloudMonkey ${CLOUDMONKEY_VERSION} Installation Script"
    echo ""
    
    check_root
    check_existing
    
    # Detect system architecture
    binary_file=$(detect_architecture)
    
    log_info "Detected OS: $(uname -s)"
    log_info "Detected Architecture: $(uname -m)"
    log_info "Target binary: $binary_file"
    echo ""
    
    # Download and install
    log_info "Downloading CloudMonkey ${CLOUDMONKEY_VERSION}..."
    log_info "URL: ${GITHUB_RELEASE_URL}/${CLOUDMONKEY_VERSION}/${binary_file}"
    temp_file=$(download_cloudmonkey "$binary_file")
    
    install_cloudmonkey "$temp_file"
    
    # Verify and show usage
    if verify_installation; then
        print_usage
        # print_checksums
    else
        exit 1
    fi
}

main "$@"

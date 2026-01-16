#!/bin/bash
# CloudMonkey Installation Script
# Downloads and installs CloudMonkey for Linux x86-64

set -e

# Configuration
CLOUDMONKEY_VERSION="6.5.0"
GITHUB_RELEASE_URL="https://github.com/apache/cloudstack-cloudmonkey/releases/download"
BINARY_FILE="cmk.linux.x86-64"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="cmk"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_existing() {
    if command -v cmk &> /dev/null; then
        echo "CloudMonkey is already installed: $(cmk --version 2>&1 | head -1)"
        read -p "Reinstall? (y/n): " reinstall
        if [[ "$reinstall" != "y" ]]; then
            exit 0
        fi
    fi
}

download_and_install() {
    local download_url="${GITHUB_RELEASE_URL}/${CLOUDMONKEY_VERSION}/${BINARY_FILE}"
    local temp_file="/tmp/${BINARY_FILE}"
    local install_path="${INSTALL_DIR}/${BINARY_NAME}"
    
    echo "Downloading CloudMonkey ${CLOUDMONKEY_VERSION}..."
    
    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "$temp_file" "$download_url"
    elif command -v curl &> /dev/null; then
        curl -# -L -o "$temp_file" "$download_url"
    else
        log_error "wget or curl is required"
        exit 1
    fi
    
    chmod +x "$temp_file"
    mv "$temp_file" "$install_path"
    
    log_info "CloudMonkey installed to ${install_path}"
}

verify_installation() {
    if ! command -v cmk &> /dev/null; then
        log_error "Installation failed"
        exit 1
    fi
    
    log_info "Installation complete: $(cmk --version 2>&1 | head -1)"
}

print_next_steps() {
    echo ""
    echo "Next Steps:"
    echo "1. Configure CloudMonkey:"
    echo "   cmk set url http://YOUR-MGMT-SERVER:8080/client/api"
    echo "   cmk set apikey YOUR-API-KEY"
    echo "   cmk set secretkey YOUR-SECRET-KEY"
    echo ""
    echo "2. Test connection:"
    echo "   cmk list zones"
    echo ""
}

main() {
    check_root
    check_existing
    download_and_install
    verify_installation
    print_next_steps
}

main "$@"

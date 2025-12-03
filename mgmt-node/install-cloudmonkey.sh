#!/bin/bash
# CloudMonkey Installation Script
# Installs CloudMonkey CLI tool for CloudStack API interaction
#
# Usage: sudo ./install-cloudmonkey.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_existing() {
    if command -v cmk &> /dev/null; then
        log_info "CloudMonkey is already installed"
        cmk --version
        read -p "Reinstall? (yes/no): " reinstall
        if [[ "$reinstall" != "yes" ]]; then
            log_info "Installation skipped"
            exit 0
        fi
    fi
}

install_dependencies() {
    log_info "Installing dependencies..."
    apt-get update -y
    apt-get install -y python3 python3-pip
}

install_cloudmonkey() {
    log_info "Installing CloudMonkey via pip3..."
    pip3 install cloudmonkey
    
    # Create symlink if needed
    if ! command -v cmk &> /dev/null; then
        if [[ -f /usr/local/bin/cmk ]]; then
            ln -sf /usr/local/bin/cmk /usr/bin/cmk
        elif [[ -f ~/.local/bin/cmk ]]; then
            ln -sf ~/.local/bin/cmk /usr/bin/cmk
        fi
    fi
}

verify_installation() {
    log_info "Verifying installation..."
    
    if command -v cmk &> /dev/null; then
        log_info "CloudMonkey installed successfully!"
        cmk --version
        echo ""
        log_info "CloudMonkey command: cmk"
        log_info "Help: cmk help"
        log_info "List commands: cmk list"
        return 0
    else
        log_error "CloudMonkey installation failed!"
        return 1
    fi
}

print_usage() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          CloudMonkey Installation Complete!               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Basic Usage:"
    echo "  cmk help                    - Show help"
    echo "  cmk list zones              - List zones"
    echo "  cmk list hosts              - List hosts"
    echo ""
    echo "Configuration:"
    echo "  cmk set profile myprofile"
    echo "  cmk set url http://management-server:8080/client/api"
    echo "  cmk set apikey YOUR_API_KEY"
    echo "  cmk set secretkey YOUR_SECRET_KEY"
    echo ""
    echo "Get API Keys:"
    echo "  1. Login to CloudStack UI"
    echo "  2. Accounts → admin → View Users → admin"
    echo "  3. Keys tab → Generate Keys"
    echo ""
}

main() {
    log_info "Starting CloudMonkey installation..."
    
    if [[ $EUID -ne 0 ]]; then
        log_warn "This script should be run as root"
        log_warn "Some features may not work without root privileges"
    fi
    
    check_existing
    install_dependencies
    install_cloudmonkey
    
    if verify_installation; then
        print_usage
    else
        exit 1
    fi
}

main "$@"

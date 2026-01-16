#!/bin/bash
# Ansible Controller Setup Script
# This script prepares the Ansible controller for CloudStack deployment

set -e

# Get actual user when running with sudo
if [[ -n "$SUDO_USER" ]]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(eval echo ~$SUDO_USER)
else
    ACTUAL_USER="$USER"
    ACTUAL_HOME="$HOME"
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         CloudStack Ansible Controller Setup                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

check_os() {
    log_info "Checking operating system..."
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_info "OS: $NAME $VERSION"
    else
        log_error "Cannot determine OS"
        exit 1
    fi
}

install_ansible() {
    log_info "Installing Ansible..."
    
    if command -v ansible &> /dev/null; then
        log_warn "Ansible is already installed: $(ansible --version | head -1)"
        return 0
    fi
    
    sudo apt-get update -y
    sudo apt-get install -y ansible
    
    log_info "✓ Ansible installed: $(ansible --version | head -1)"
}

install_dependencies() {
    log_info "Installing dependencies..."
    sudo apt-get install -y \
        python3-pip \
        python3-netaddr \
        sshpass
    
    log_info "✓ Dependencies installed"
}

setup_ssh_config() {
    log_info "Configuring SSH client for user: $ACTUAL_USER..."
    
    mkdir -p "$ACTUAL_HOME/.ssh"
    chmod 700 "$ACTUAL_HOME/.ssh"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.ssh"
    
    if [[ ! -f "$ACTUAL_HOME/.ssh/config" ]]; then
        cat > "$ACTUAL_HOME/.ssh/config" <<EOF
# SSH Configuration for CloudStack deployment
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 "$ACTUAL_HOME/.ssh/config"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.ssh/config"
        log_info "✓ SSH config created"
    else
        log_warn "SSH config already exists"
    fi
}

print_next_steps() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    Setup Complete!                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Ansible Controller is ready for user: $ACTUAL_USER"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Next Steps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Configure inventory:"
    echo "   cd cloudstack/"
    echo "   cp inventory/hosts.example inventory/hosts"
    echo "   vi inventory/hosts"
    echo ""
    echo "2. Configure passwords:"
    echo "   vi inventory/group_vars/all/vault.yml"
    echo ""
    echo "3. Configure network settings:"
    echo "   vi inventory/group_vars/all/all.yml"
    echo ""
    echo "4. Copy SSH keys to target servers:"
    echo "   ./copy-ssh-keys.sh"
    echo ""
    echo "5. Test connectivity:"
    echo "   ansible all -i inventory/hosts -m ping"
    echo ""
    echo "6. Deploy CloudStack:"
    echo "   ansible-playbook -i inventory/hosts playbooks/site.yml"
    echo ""
}

# Main execution
main() {
    print_header
    check_os
    install_ansible
    install_dependencies
    setup_ssh_config
    print_next_steps
}

main "$@"

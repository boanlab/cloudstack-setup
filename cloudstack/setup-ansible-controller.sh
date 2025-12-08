#!/bin/bash
# Ansible Controller Setup Script
# This script prepares the Ansible controller for CloudStack deployment

set -e

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
    echo "║     CloudStack Ansible Controller Setup Script            ║"
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
    
    log_info "Ansible installed: $(ansible --version | head -1)"
}

install_sshpass() {
    log_info "Installing sshpass (for password authentication)..."
    
    if command -v sshpass &> /dev/null; then
        log_warn "sshpass is already installed"
        return 0
    fi
    
    sudo apt-get install -y sshpass
    log_info "sshpass installed"
}

install_dependencies() {
    log_info "Installing additional dependencies..."
    sudo apt-get install -y \
        python3-pip \
        python3-netaddr \
        git \
        vim \
        curl
    
    log_info "Dependencies installed"
}

setup_ssh_config() {
    log_info "Configuring SSH client..."
    
    # Create SSH config if doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    if [[ ! -f ~/.ssh/config ]]; then
        cat > ~/.ssh/config <<EOF
# SSH Configuration for CloudStack deployment
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 ~/.ssh/config
        log_info "SSH config created"
    else
        log_warn "SSH config already exists"
    fi
}

check_inventory() {
    log_info "Checking Ansible inventory..."
    
    if [[ ! -f inventory/hosts ]]; then
        log_warn "inventory/hosts not found!"
        if [[ -f inventory/hosts.example ]]; then
            log_info "Example inventory found. Please copy and configure:"
            echo "  cp inventory/hosts.example inventory/hosts"
            echo "  vi inventory/hosts"
        fi
    else
        log_info "Inventory file exists"
    fi
}

check_vault() {
    log_info "Checking vault configuration..."
    
    if [[ ! -f group_vars/vault.yml ]]; then
        log_warn "group_vars/vault.yml not found!"
        if [[ -f group_vars/vault.yml.example ]]; then
            log_info "Example vault found. Please copy and configure:"
            echo "  cp group_vars/vault.yml.example group_vars/vault.yml"
            echo "  vi group_vars/vault.yml"
        fi
    else
        log_info "Vault file exists"
    fi
}

generate_ssh_key() {
    log_info "Checking SSH key..."
    
    if [[ -f ~/.ssh/id_rsa ]]; then
        log_warn "SSH key already exists"
        return 0
    fi
    
    read -p "Generate SSH key? (y/n): " response
    if [[ "$response" == "y" ]]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        log_info "SSH key generated"
        echo ""
        log_info "Copy this key to your target servers:"
        echo "  ssh-copy-id user@target-server"
    fi
}

test_connection() {
    log_info "Testing Ansible connectivity..."
    
    if [[ ! -f inventory/hosts ]]; then
        log_warn "Skipping connectivity test (no inventory)"
        return 0
    fi
    
    echo ""
    log_info "Running: ansible all -i inventory/hosts -m ping"
    echo ""
    
    if ansible all -i inventory/hosts -m ping; then
        log_info "All hosts are reachable!"
    else
        log_warn "Some hosts are not reachable. Check your inventory and SSH access."
    fi
}

print_next_steps() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              Setup Complete!                               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Configure inventory (if not already done):"
    echo "   cp inventory/hosts.example inventory/hosts"
    echo "   vi inventory/hosts"
    echo ""
    echo "2. Configure vault with passwords:"
    echo "   cp group_vars/vault.yml.example group_vars/vault.yml"
    echo "   vi group_vars/vault.yml"
    echo ""
    echo "3. Configure network CIDRs in group_vars/all.yml:"
    echo "   vi group_vars/all.yml"
    echo ""
    echo "4. (Optional) Copy SSH key to target servers:"
    echo "   ssh-copy-id user@target-server"
    echo ""
    echo "5. Test connectivity:"
    echo "   ansible all -i inventory/hosts -m ping --ask-pass"
    echo ""
    echo "6. Run deployment:"
    echo "   ansible-playbook -i inventory/hosts playbooks/site.yml --ask-pass --ask-become-pass"
    echo ""
}

# Main execution
main() {
    print_header
    check_os
    install_ansible
    install_sshpass
    install_dependencies
    setup_ssh_config
    check_inventory
    check_vault
    generate_ssh_key
    test_connection
    print_next_steps
}

main "$@"

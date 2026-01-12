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
    echo "║         CloudStack Ansible Controller Setup Script         ║"
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
    log_info "Configuring SSH client for user: $ACTUAL_USER..."
    
    # Create SSH config if doesn't exist
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
        log_info "SSH config created at $ACTUAL_HOME/.ssh/config"
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
    log_info "Checking SSH key for user: $ACTUAL_USER..."
    
    if [[ -f "$ACTUAL_HOME/.ssh/id_rsa" ]]; then
        log_warn "SSH key already exists at $ACTUAL_HOME/.ssh/id_rsa"
        return 0
    fi
    
    read -p "Generate SSH key? (y/n): " response
    if [[ "$response" == "y" ]]; then
        sudo -u "$ACTUAL_USER" ssh-keygen -t rsa -b 4096 -f "$ACTUAL_HOME/.ssh/id_rsa" -N ""
        log_info "SSH key generated at $ACTUAL_HOME/.ssh/id_rsa"
    fi
}

copy_ssh_keys() {
    log_info "SSH key authentication setup..."
    
    if [[ ! -f "$ACTUAL_HOME/.ssh/id_rsa.pub" ]]; then
        log_error "SSH public key not found at $ACTUAL_HOME/.ssh/id_rsa.pub. Please generate one first."
        return 1
    fi
    
    if [[ ! -f inventory/hosts ]]; then
        log_warn "inventory/hosts not found. Skipping SSH key distribution."
        return 0
    fi
    
    # Extract all ansible_host IPs from inventory
    local hosts=$(grep -oP 'ansible_host=\K[0-9.]+' inventory/hosts | sort -u)
    
    if [[ -z "$hosts" ]]; then
        log_warn "No hosts found in inventory"
        return 0
    fi
    
    # Get ansible_user from inventory (default to root if not found)
    local ansible_user=$(grep -oP 'ansible_user=\K\w+' inventory/hosts | head -1)
    ansible_user=${ansible_user:-root}
    
    echo ""
    read -p "Copy SSH keys to all target servers now? (y/n): " response
    
    if [[ "$response" != "y" ]]; then
        log_info "Skipping SSH key copy. You can manually run as $ACTUAL_USER:"
        echo ""
        for host in $hosts; do
            echo "  ssh-copy-id $ansible_user@$host"
        done
        echo ""
        return 0
    fi
    
    echo ""
    log_info "Copying SSH keys to target servers..."
    log_warn "You will be prompted for password for each server"
    echo ""
    
    for host in $hosts; do
        log_info "Copying key to $ansible_user@$host..."
        if sudo -u "$ACTUAL_USER" ssh-copy-id -i "$ACTUAL_HOME/.ssh/id_rsa.pub" $ansible_user@$host; then
            log_info "✓ Key copied to $host"
        else
            log_error "✗ Failed to copy key to $host"
        fi
        echo ""
    done
}

test_connection() {
    log_info "Connectivity test information..."
    
    if [[ ! -f inventory/hosts ]]; then
        log_warn "Skipping connectivity test (no inventory)"
        return 0
    fi
    
    echo ""
    log_info "To test connectivity to all hosts, run:"
    echo "  ansible all -i inventory/hosts -m ping"
    echo ""
}

print_next_steps() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              Setup Complete!                               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "SSH keys configured for user: $ACTUAL_USER"
    log_info "SSH key location: $ACTUAL_HOME/.ssh/id_rsa"
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
    echo "4. Copy SSH keys to all target servers (manually):"
    echo "   ssh-copy-id user@target-host"
    echo ""
    echo "5. Test connectivity:"
    echo "   ansible all -i inventory/hosts -m ping"
    echo ""
    echo "6. Run deployment:"
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
    check_inventory
    check_vault
    generate_ssh_key
    copy_ssh_keys
    test_connection
    print_next_steps
}

main "$@"

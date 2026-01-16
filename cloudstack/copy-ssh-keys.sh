#!/bin/bash
# SSH Key Distribution Script
# This script copies SSH public key to all target servers in inventory

set -e

# Get actual user
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
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              SSH Key Distribution Script                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

generate_ssh_key() {
    log_info "Checking SSH key for user: $ACTUAL_USER..."
    
    if [[ -f "$ACTUAL_HOME/.ssh/id_rsa" ]]; then
        log_info "✓ SSH key already exists at $ACTUAL_HOME/.ssh/id_rsa"
        return 0
    fi
    
    log_warn "SSH key not found. Generating new key..."
    echo ""
    read -p "Generate new SSH key? (y/n): " response
    
    if [[ "$response" != "y" ]]; then
        log_error "SSH key is required to continue"
        exit 1
    fi
    
    log_info "Generating SSH key..."
    sudo -u "$ACTUAL_USER" ssh-keygen -t rsa -b 4096 -f "$ACTUAL_HOME/.ssh/id_rsa" -N ""
    log_info "✓ SSH key generated at $ACTUAL_HOME/.ssh/id_rsa"
}

check_inventory() {
    log_info "Checking inventory file..."
    
    if [[ ! -f inventory/hosts ]]; then
        log_error "inventory/hosts not found"
        log_info "Please create inventory file first:"
        echo "  cp inventory/hosts.example inventory/hosts"
        echo "  vi inventory/hosts"
        exit 1
    fi
    
    log_info "✓ Inventory file found"
}

extract_hosts() {
    log_info "Extracting hosts from inventory..."
    
    # Extract all ansible_host IPs from inventory
    HOSTS=$(grep -oP 'ansible_host=\K[0-9.]+' inventory/hosts | sort -u)
    
    if [[ -z "$HOSTS" ]]; then
        log_error "No hosts found in inventory/hosts"
        exit 1
    fi
    
    # Get ansible_user from inventory (default to root if not found)
    ANSIBLE_USER=$(grep -oP 'ansible_user=\K\w+' inventory/hosts | head -1)
    ANSIBLE_USER=${ANSIBLE_USER:-root}
    
    HOST_COUNT=$(echo "$HOSTS" | wc -l)
    log_info "Found $HOST_COUNT host(s) with user: $ANSIBLE_USER"
    echo ""
    echo "Target hosts:"
    for host in $HOSTS; do
        echo "  • $ANSIBLE_USER@$host"
    done
    echo ""
}

copy_keys() {
    echo ""
    read -p "Copy SSH key to all hosts? (y/n): " response
    
    if [[ "$response" != "y" ]]; then
        log_info "Cancelled by user"
        exit 0
    fi
    
    echo ""
    log_info "Starting SSH key distribution..."
    log_warn "You will be prompted for password for each server"
    echo ""
    
    local success_count=0
    local fail_count=0
    local failed_hosts=()
    
    for host in $HOSTS; do
        log_step "Copying key to $ANSIBLE_USER@$host..."
        
        if sudo -u "$ACTUAL_USER" ssh-copy-id -i "$ACTUAL_HOME/.ssh/id_rsa.pub" $ANSIBLE_USER@$host 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Key copied to $host"
            ((success_count++))
        else
            echo -e "${RED}✗${NC} Failed to copy key to $host"
            ((fail_count++))
            failed_hosts+=("$host")
        fi
        echo ""
    done
    
    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Success: $success_count host(s)"
    
    if [[ $fail_count -gt 0 ]]; then
        log_error "Failed: $fail_count host(s)"
        echo ""
        echo "Failed hosts:"
        for host in "${failed_hosts[@]}"; do
            echo "  • $ANSIBLE_USER@$host"
        done
        echo ""
        log_info "You can retry manually with:"
        for host in "${failed_hosts[@]}"; do
            echo "  ssh-copy-id $ANSIBLE_USER@$host"
        done
    fi
    echo ""
}

print_next_steps() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Next Steps"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Test connectivity:"
    echo "   ansible all -i inventory/hosts -m ping"
    echo ""
    echo "2. Deploy CloudStack:"
    echo "   ansible-playbook -i inventory/hosts playbooks/site.yml"
    echo ""
}

# Main execution
main() {
    print_header
    generate_ssh_key
    check_inventory
    extract_hosts
    copy_keys
    print_next_steps
}

main "$@"

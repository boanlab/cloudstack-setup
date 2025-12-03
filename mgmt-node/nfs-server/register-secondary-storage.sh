#!/bin/bash
# CloudStack Secondary Storage Registration Script
# Uses CloudMonkey to register NFS secondary storage
#
# Usage: ./register-secondary-storage.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLOUDSTACK_URL=""
API_KEY=""
SECRET_KEY=""
NFS_SERVER=""
NFS_PATH="/export/secondary"
ZONE_NAME=""

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_cloudmonkey() {
    if ! command -v cmk &> /dev/null; then
        log_error "CloudMonkey (cmk) is not installed!"
        echo ""
        echo "Install CloudMonkey:"
        echo "  pip3 install cloudmonkey"
        echo ""
        echo "Or using apt:"
        echo "  sudo apt-get install cloudmonkey"
        exit 1
    fi
    
    log_info "CloudMonkey is installed: $(cmk --version 2>&1 | head -1)"
}

get_user_input() {
    log_info "CloudStack Secondary Storage Registration"
    echo ""
    
    # CloudStack connection info
    if [[ -z "$CLOUDSTACK_URL" ]]; then
        read -p "Enter CloudStack Management Server URL (e.g., http://10.0.0.11:8080/client/api): " CLOUDSTACK_URL
    fi
    
    if [[ -z "$API_KEY" ]]; then
        read -p "Enter API Key: " API_KEY
    fi
    
    if [[ -z "$SECRET_KEY" ]]; then
        read -sp "Enter Secret Key: " SECRET_KEY
        echo ""
    fi
    
    # NFS server info
    if [[ -z "$NFS_SERVER" ]]; then
        read -p "Enter NFS Server IP: " NFS_SERVER
    fi
    
    if [[ -z "$NFS_PATH" ]]; then
        read -p "Enter NFS Path [/export/secondary]: " NFS_PATH
        NFS_PATH=${NFS_PATH:-/export/secondary}
    fi
    
    # Zone info
    if [[ -z "$ZONE_NAME" ]]; then
        read -p "Enter Zone Name: " ZONE_NAME
    fi
    
    echo ""
    log_info "Configuration:"
    echo "  CloudStack URL: $CLOUDSTACK_URL"
    echo "  NFS Server: nfs://${NFS_SERVER}${NFS_PATH}"
    echo "  Zone: $ZONE_NAME"
    echo ""
    
    read -p "Continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_warn "Registration cancelled"
        exit 0
    fi
}

configure_cloudmonkey() {
    log_info "Configuring CloudMonkey..."
    
    # Create CloudMonkey config
    cmk set profile cloudstack-admin
    cmk set url "$CLOUDSTACK_URL"
    cmk set apikey "$API_KEY"
    cmk set secretkey "$SECRET_KEY"
    cmk set display table
    cmk set timeout 3600
    
    log_info "CloudMonkey configured"
}

test_connection() {
    log_info "Testing CloudStack connection..."
    
    if ! cmk list zones 2>&1 | grep -q "id"; then
        log_error "Failed to connect to CloudStack!"
        log_error "Please check your URL, API Key, and Secret Key"
        exit 1
    fi
    
    log_info "Connection successful"
}

get_zone_id() {
    log_info "Getting Zone ID for '$ZONE_NAME'..."
    
    local zone_id=$(cmk list zones filter=id,name | grep -A1 "$ZONE_NAME" | grep "id" | awk '{print $3}')
    
    if [[ -z "$zone_id" ]]; then
        log_error "Zone '$ZONE_NAME' not found!"
        echo ""
        log_info "Available zones:"
        cmk list zones filter=id,name
        exit 1
    fi
    
    echo "$zone_id"
}

check_existing_secondary_storage() {
    local zone_id=$1
    
    log_info "Checking for existing secondary storage..."
    
    local existing=$(cmk list imagestores zoneid="$zone_id" filter=id,name,url 2>/dev/null || echo "")
    
    if [[ -n "$existing" ]]; then
        log_warn "Existing secondary storage found:"
        echo "$existing"
        echo ""
        read -p "Continue anyway? (yes/no): " continue_anyway
        if [[ "$continue_anyway" != "yes" ]]; then
            log_warn "Registration cancelled"
            exit 0
        fi
    fi
}

register_secondary_storage() {
    local zone_id=$1
    local nfs_url="nfs://${NFS_SERVER}${NFS_PATH}"
    
    log_info "Registering secondary storage..."
    log_info "URL: $nfs_url"
    log_info "Zone ID: $zone_id"
    
    local result=$(cmk add imagestore \
        name="NFS-Secondary-Storage" \
        provider="NFS" \
        zoneid="$zone_id" \
        url="$nfs_url" 2>&1)
    
    if echo "$result" | grep -q "id"; then
        log_info "Secondary storage registered successfully!"
        echo ""
        echo "$result"
        return 0
    else
        log_error "Failed to register secondary storage!"
        echo "$result"
        return 1
    fi
}

verify_secondary_storage() {
    local zone_id=$1
    
    log_info "Verifying secondary storage registration..."
    
    local stores=$(cmk list imagestores zoneid="$zone_id" filter=id,name,url,zonename,scope)
    
    if [[ -n "$stores" ]]; then
        log_info "Registered secondary storage:"
        echo "$stores"
        return 0
    else
        log_warn "No secondary storage found for zone"
        return 1
    fi
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║    Secondary Storage Registration Complete!               ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  NFS Server: ${NFS_SERVER}"
    echo "║  NFS Path: ${NFS_PATH}"
    echo "║  Zone: ${ZONE_NAME}"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "1. Verify in CloudStack UI: Infrastructure → Secondary Storage"
    echo "2. Wait for system VMs to be created"
    echo "3. Check Secondary Storage VM status"
    echo ""
}

print_api_key_help() {
    echo ""
    log_info "How to get API Key and Secret Key:"
    echo ""
    echo "1. Login to CloudStack UI as admin"
    echo "2. Go to: Accounts → admin → View Users"
    echo "3. Click on 'admin' user"
    echo "4. Go to 'Keys' tab"
    echo "5. Click 'Generate Keys' or use existing keys"
    echo ""
}

# Main execution
main() {
    log_info "Starting CloudStack Secondary Storage Registration..."
    
    check_cloudmonkey
    
    # Show help if no args
    if [[ $# -eq 0 ]]; then
        print_api_key_help
    fi
    
    get_user_input
    configure_cloudmonkey
    test_connection
    
    zone_id=$(get_zone_id)
    log_info "Zone ID: $zone_id"
    
    check_existing_secondary_storage "$zone_id"
    
    if register_secondary_storage "$zone_id"; then
        sleep 3
        verify_secondary_storage "$zone_id"
        print_summary
        log_info "Registration completed successfully!"
    else
        log_error "Registration failed!"
        exit 1
    fi
}

# Run main function
main "$@"

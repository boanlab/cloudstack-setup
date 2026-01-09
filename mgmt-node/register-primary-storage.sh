#!/bin/bash
# CloudStack Primary Storage Registration Script
# Uses CloudMonkey to register NFS primary storage
#
# Usage: ./register-primary-storage.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NFS_SERVER=""
NFS_PATH="/export/primary"
ZONE_NAME=""
POD_NAME=""
CLUSTER_NAME=""
STORAGE_NAME=""

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

check_cloudmonkey_config() {
    log_info "Checking CloudMonkey configuration..."
    
    # Check if config file exists
    local config_file="$HOME/.cmk/config"
    if [[ ! -f "$config_file" ]]; then
        log_error "CloudMonkey is not configured!"
        print_config_help
        exit 1
    fi
    
    # Check if required fields are set
    local url=$(grep "^url" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    local apikey=$(grep "^apikey" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    local secretkey=$(grep "^secretkey" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    
    if [[ -z "$url" ]] || [[ -z "$apikey" ]] || [[ -z "$secretkey" ]]; then
        log_error "CloudMonkey configuration is incomplete!"
        print_config_help
        exit 1
    fi
    
    log_info "CloudMonkey configuration found"
    log_info "URL: $url"
}

get_user_input() {
    log_info "CloudStack Primary Storage Registration"
    echo ""
    
    # NFS server info
    if [[ -z "$NFS_SERVER" ]]; then
        read -p "Enter NFS Server IP: " NFS_SERVER
    fi
    
    if [[ -z "$NFS_PATH" ]]; then
        read -p "Enter NFS Path [/export/primary]: " NFS_PATH
        NFS_PATH=${NFS_PATH:-/export/primary}
    fi
    
    # Storage name
    if [[ -z "$STORAGE_NAME" ]]; then
        read -p "Enter Storage Name [Primary-Storage-1]: " STORAGE_NAME
        STORAGE_NAME=${STORAGE_NAME:-Primary-Storage-1}
    fi
    
    # Zone info
    if [[ -z "$ZONE_NAME" ]]; then
        read -p "Enter Zone Name: " ZONE_NAME
    fi
    
    # Pod info
    if [[ -z "$POD_NAME" ]]; then
        read -p "Enter Pod Name: " POD_NAME
    fi
    
    # Cluster info
    if [[ -z "$CLUSTER_NAME" ]]; then
        read -p "Enter Cluster Name: " CLUSTER_NAME
    fi
    
    echo ""
    log_info "Configuration:"
    echo "  NFS Server: nfs://${NFS_SERVER}${NFS_PATH}"
    echo "  Storage Name: $STORAGE_NAME"
    echo "  Zone: $ZONE_NAME"
    echo "  Pod: $POD_NAME"
    echo "  Cluster: $CLUSTER_NAME"
    echo ""
    
    read -p "Continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_warn "Registration cancelled"
        exit 0
    fi
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
    
    local zone_id=$(cmk list zones filter=id,name | grep -B1 "$ZONE_NAME" | grep "id" | awk '{print $3}')
    
    if [[ -z "$zone_id" ]]; then
        log_error "Zone '$ZONE_NAME' not found!"
        echo ""
        log_info "Available zones:"
        cmk list zones filter=id,name
        exit 1
    fi
    
    echo "$zone_id"
}

get_pod_id() {
    local zone_id=$1
    
    log_info "Getting Pod ID for '$POD_NAME'..."
    
    local pod_id=$(cmk list pods zoneid="$zone_id" filter=id,name | grep -B1 "$POD_NAME" | grep "id" | awk '{print $3}')
    
    if [[ -z "$pod_id" ]]; then
        log_error "Pod '$POD_NAME' not found in zone '$ZONE_NAME'!"
        echo ""
        log_info "Available pods:"
        cmk list pods zoneid="$zone_id" filter=id,name
        exit 1
    fi
    
    echo "$pod_id"
}

get_cluster_id() {
    local zone_id=$1
    
    log_info "Getting Cluster ID for '$CLUSTER_NAME'..."
    
    local cluster_id=$(cmk list clusters zoneid="$zone_id" filter=id,name | grep -B1 "$CLUSTER_NAME" | grep "id" | awk '{print $3}')
    
    if [[ -z "$cluster_id" ]]; then
        log_error "Cluster '$CLUSTER_NAME' not found in zone '$ZONE_NAME'!"
        echo ""
        log_info "Available clusters:"
        cmk list clusters zoneid="$zone_id" filter=id,name
        exit 1
    fi
    
    echo "$cluster_id"
}

check_existing_primary_storage() {
    local cluster_id=$1
    
    log_info "Checking for existing primary storage in cluster..."
    
    local existing=$(cmk list storagepools clusterid="$cluster_id" filter=id,name,ipaddress,path 2>/dev/null || echo "")
    
    if [[ -n "$existing" ]]; then
        log_warn "Existing primary storage found in cluster:"
        echo "$existing"
        echo ""
        read -p "Continue anyway? (yes/no): " continue_anyway
        if [[ "$continue_anyway" != "yes" ]]; then
            log_warn "Registration cancelled"
            exit 0
        fi
    fi
}

register_primary_storage() {
    local zone_id=$1
    local pod_id=$2
    local cluster_id=$3
    
    log_info "Registering primary storage..."
    log_info "Name: $STORAGE_NAME"
    log_info "Server: $NFS_SERVER"
    log_info "Path: $NFS_PATH"
    log_info "Cluster ID: $cluster_id"
    
    local result=$(cmk create storagepool \
        name="$STORAGE_NAME" \
        scope="cluster" \
        zoneid="$zone_id" \
        podid="$pod_id" \
        clusterid="$cluster_id" \
        url="nfs://${NFS_SERVER}${NFS_PATH}" 2>&1)
    
    if echo "$result" | grep -q "id"; then
        log_info "Primary storage registered successfully!"
        echo ""
        echo "$result"
        return 0
    else
        log_error "Failed to register primary storage!"
        echo "$result"
        return 1
    fi
}

verify_primary_storage() {
    local cluster_id=$1
    
    log_info "Verifying primary storage registration..."
    
    local pools=$(cmk list storagepools clusterid="$cluster_id" filter=id,name,ipaddress,path,state,scope)
    
    if [[ -n "$pools" ]]; then
        log_info "Registered primary storage:"
        echo "$pools"
        return 0
    else
        log_warn "No primary storage found for cluster"
        return 1
    fi
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║      Primary Storage Registration Complete!               ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  Storage Name: ${STORAGE_NAME}"
    echo "║  NFS Server: ${NFS_SERVER}"
    echo "║  NFS Path: ${NFS_PATH}"
    echo "║  Zone: ${ZONE_NAME}"
    echo "║  Pod: ${POD_NAME}"
    echo "║  Cluster: ${CLUSTER_NAME}"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "1. Verify in CloudStack UI: Infrastructure → Primary Storage"
    echo "2. Check storage pool state (should be 'Up')"
    echo "3. Deploy VMs to test storage"
    echo ""
}

print_config_help() {
    echo ""
    log_error "Please configure CloudMonkey first!"
    echo ""
    echo "Steps to configure CloudMonkey:"
    echo ""
    echo "1. Get API credentials from CloudStack UI:"
    echo "   - Login to CloudStack UI as admin"
    echo "   - Go to: Accounts → admin → View Users"
    echo "   - Click on 'admin' user"
    echo "   - Go to 'Keys' tab"
    echo "   - Click 'Generate Keys' or use existing keys"
    echo ""
    echo "2. Configure CloudMonkey:"
    echo "   cmk set url http://YOUR-MGMT-SERVER:8080/client/api"
    echo "   cmk set apikey YOUR-API-KEY"
    echo "   cmk set secretkey YOUR-SECRET-KEY"
    echo "   cmk set display table"
    echo ""
    echo "3. Test connection:"
    echo "   cmk list zones"
    echo ""
}

# Main execution
main() {
    log_info "Starting CloudStack Primary Storage Registration..."
    
    check_cloudmonkey
    check_cloudmonkey_config
    
    get_user_input
    test_connection
    
    zone_id=$(get_zone_id)
    log_info "Zone ID: $zone_id"
    
    pod_id=$(get_pod_id "$zone_id")
    log_info "Pod ID: $pod_id"
    
    cluster_id=$(get_cluster_id "$zone_id")
    log_info "Cluster ID: $cluster_id"
    
    check_existing_primary_storage "$cluster_id"
    
    if register_primary_storage "$zone_id" "$pod_id" "$cluster_id"; then
        sleep 3
        verify_primary_storage "$cluster_id"
        print_summary
        log_info "Registration completed successfully!"
    else
        log_error "Registration failed!"
        exit 1
    fi
}

# Run main function
main "$@"

#!/bin/bash
# CloudStack Zone Setup Script using CloudMonkey
# This script configures a complete CloudStack zone using the cmk CLI
# Usage: ./setup-cloudstack-zone.sh <config-file.yml>

set -e

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
    echo ""
    echo -e "${BLUE}==>${NC} $1"
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║       CloudStack Zone Setup Script (CloudMonkey)          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

show_help() {
    echo "CloudStack Zone Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS] <config-file.yml>"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Arguments:"
    echo "  config-file.yml    YAML configuration file for zone setup"
    echo ""
    echo "Example:"
    echo "  cp zone-config.yml.example zone-config.yml"
    echo "  vi zone-config.yml"
    echo "  $0 zone-config.yml"
    echo ""
    echo "Requirements:"
    echo "  - CloudMonkey (cmk) must be installed"
    echo "  - yq must be installed for YAML parsing"
    echo "  - Valid CloudStack API credentials"
    echo ""
}

# Configuration variables (no defaults - must be set from YAML)
CONFIG_FILE=""
CLOUDSTACK_URL=""
CLOUDSTACK_API_KEY=""
CLOUDSTACK_SECRET_KEY=""
ZONE_NAME=""
ZONE_DNS1=""
ZONE_DNS2=""
ZONE_INTERNAL_DNS1=""
ZONE_INTERNAL_DNS2=""
ZONE_NETWORK_TYPE=""
ZONE_GUEST_CIDR=""
PHYSICAL_NETWORK_NAME=""
ISOLATION_METHOD=""
VLAN_RANGE=""
MANAGEMENT_LABEL=""
GUEST_LABEL=""
PUBLIC_LABEL=""
STORAGE_LABEL=""
PUBLIC_START_IP=""
PUBLIC_END_IP=""
PUBLIC_GATEWAY=""
PUBLIC_NETMASK=""
PUBLIC_VLAN=""
POD_NAME=""
POD_GATEWAY=""
POD_NETMASK=""
POD_START_IP=""
POD_END_IP=""
CLUSTER_NAME=""
CLUSTER_HYPERVISOR=""
CLUSTER_TYPE=""
HOST_NAMES=()
HOST_IPS=()
HOST_USERNAMES=()
HOST_PASSWORDS=()
PRIMARY_STORAGE_NAME=""
PRIMARY_STORAGE_SERVER=""
PRIMARY_STORAGE_PATH=""
PRIMARY_STORAGE_SCOPE=""
SECONDARY_STORAGE_NAME=""
SECONDARY_STORAGE_SERVER=""
SECONDARY_STORAGE_PATH=""
SECONDARY_STORAGE_PROVIDER=""

check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check CloudMonkey
    if ! command -v cmk &> /dev/null; then
        log_error "CloudMonkey (cmk) is not installed"
        log_info "Please run: sudo ./install-cloudmonkey.sh"
        exit 1
    fi
    log_info "✓ CloudMonkey installed"
    
    # Check yq for YAML parsing
    if ! command -v yq &> /dev/null; then
        log_warn "yq is not installed (required for YAML parsing)"
        log_info "Installing yq..."
        
        if sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq; then
            log_info "✓ yq installed successfully"
        else
            log_error "Failed to install yq"
            log_info "Please install manually: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
            exit 1
        fi
    else
        log_info "✓ yq installed"
    fi
}

check_config_file() {
    if [[ -z "$CONFIG_FILE" ]]; then
        log_error "Configuration file not specified!"
        echo ""
        echo "Usage: $0 <config-file.yml>"
        echo ""
        echo "Example:"
        echo "  cp zone-config.yml.example zone-config.yml"
        echo "  vi zone-config.yml"
        echo "  $0 zone-config.yml"
        exit 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_info "Using configuration file: $CONFIG_FILE"
}

load_yaml_config() {
    log_info "Loading configuration from YAML..."
    
    # CloudStack API settings
    CLOUDSTACK_URL=$(yq eval '.cloudstack.url' "$CONFIG_FILE")
    CLOUDSTACK_API_KEY=$(yq eval '.cloudstack.api_key' "$CONFIG_FILE")
    CLOUDSTACK_SECRET_KEY=$(yq eval '.cloudstack.secret_key' "$CONFIG_FILE")
    
    # Zone configuration
    ZONE_NAME=$(yq eval '.zone.name' "$CONFIG_FILE")
    ZONE_DNS1=$(yq eval '.zone.dns1' "$CONFIG_FILE")
    ZONE_DNS2=$(yq eval '.zone.dns2' "$CONFIG_FILE")
    ZONE_INTERNAL_DNS1=$(yq eval '.zone.internal_dns1' "$CONFIG_FILE")
    ZONE_INTERNAL_DNS2=$(yq eval '.zone.internal_dns2' "$CONFIG_FILE")
    ZONE_NETWORK_TYPE=$(yq eval '.zone.network_type' "$CONFIG_FILE")
    ZONE_GUEST_CIDR=$(yq eval '.zone.guest_cidr' "$CONFIG_FILE")
    
    # Physical network
    PHYSICAL_NETWORK_NAME=$(yq eval '.physical_network.name' "$CONFIG_FILE")
    ISOLATION_METHOD=$(yq eval '.physical_network.isolation_method' "$CONFIG_FILE")
    VLAN_RANGE=$(yq eval '.physical_network.vlan_range' "$CONFIG_FILE")
    MANAGEMENT_LABEL=$(yq eval '.physical_network.traffic_labels.management' "$CONFIG_FILE")
    GUEST_LABEL=$(yq eval '.physical_network.traffic_labels.guest' "$CONFIG_FILE")
    PUBLIC_LABEL=$(yq eval '.physical_network.traffic_labels.public' "$CONFIG_FILE")
    STORAGE_LABEL=$(yq eval '.physical_network.traffic_labels.storage' "$CONFIG_FILE")
    
    # Public IP range
    PUBLIC_START_IP=$(yq eval '.public_ip_range.start_ip' "$CONFIG_FILE")
    PUBLIC_END_IP=$(yq eval '.public_ip_range.end_ip' "$CONFIG_FILE")
    PUBLIC_GATEWAY=$(yq eval '.public_ip_range.gateway' "$CONFIG_FILE")
    PUBLIC_NETMASK=$(yq eval '.public_ip_range.netmask' "$CONFIG_FILE")
    PUBLIC_VLAN=$(yq eval '.public_ip_range.vlan' "$CONFIG_FILE")
    
    # Pod
    POD_NAME=$(yq eval '.pod.name' "$CONFIG_FILE")
    POD_GATEWAY=$(yq eval '.pod.gateway' "$CONFIG_FILE")
    POD_NETMASK=$(yq eval '.pod.netmask' "$CONFIG_FILE")
    POD_START_IP=$(yq eval '.pod.start_ip' "$CONFIG_FILE")
    POD_END_IP=$(yq eval '.pod.end_ip' "$CONFIG_FILE")
    
    # Cluster
    CLUSTER_NAME=$(yq eval '.cluster.name' "$CONFIG_FILE")
    CLUSTER_HYPERVISOR=$(yq eval '.cluster.hypervisor' "$CONFIG_FILE")
    CLUSTER_TYPE=$(yq eval '.cluster.type' "$CONFIG_FILE")
    
    # Hosts (array)
    local host_count=$(yq eval '.hosts | length' "$CONFIG_FILE")
    for ((i=0; i<host_count; i++)); do
        HOST_NAMES+=("$(yq eval ".hosts[$i].name" "$CONFIG_FILE")")
        HOST_IPS+=("$(yq eval ".hosts[$i].ip" "$CONFIG_FILE")")
        HOST_USERNAMES+=("$(yq eval ".hosts[$i].username" "$CONFIG_FILE")")
        HOST_PASSWORDS+=("$(yq eval ".hosts[$i].password" "$CONFIG_FILE")")
    done
    
    # Primary storage
    PRIMARY_STORAGE_NAME=$(yq eval '.primary_storage.name' "$CONFIG_FILE")
    PRIMARY_STORAGE_SERVER=$(yq eval '.primary_storage.server' "$CONFIG_FILE")
    PRIMARY_STORAGE_PATH=$(yq eval '.primary_storage.path' "$CONFIG_FILE")
    PRIMARY_STORAGE_SCOPE=$(yq eval '.primary_storage.scope' "$CONFIG_FILE")
    
    # Secondary storage
    SECONDARY_STORAGE_NAME=$(yq eval '.secondary_storage.name' "$CONFIG_FILE")
    SECONDARY_STORAGE_SERVER=$(yq eval '.secondary_storage.server' "$CONFIG_FILE")
    SECONDARY_STORAGE_PATH=$(yq eval '.secondary_storage.path' "$CONFIG_FILE")
    SECONDARY_STORAGE_PROVIDER=$(yq eval '.secondary_storage.provider' "$CONFIG_FILE")
    
    log_info "Configuration loaded successfully"
}

validate_config() {
    log_info "Validating configuration..."
    
    local errors=0
    
    # Check required fields
    [[ -z "$CLOUDSTACK_URL" || "$CLOUDSTACK_URL" == "null" ]] && { log_error "cloudstack.url is required"; ((errors++)); }
    [[ -z "$CLOUDSTACK_API_KEY" || "$CLOUDSTACK_API_KEY" == "null" ]] && { log_error "cloudstack.api_key is required"; ((errors++)); }
    [[ -z "$CLOUDSTACK_SECRET_KEY" || "$CLOUDSTACK_SECRET_KEY" == "null" ]] && { log_error "cloudstack.secret_key is required"; ((errors++)); }
    
    [[ -z "$ZONE_NAME" || "$ZONE_NAME" == "null" ]] && { log_error "zone.name is required"; ((errors++)); }
    [[ -z "$ZONE_DNS1" || "$ZONE_DNS1" == "null" ]] && { log_error "zone.dns1 is required"; ((errors++)); }
    [[ -z "$ZONE_NETWORK_TYPE" || "$ZONE_NETWORK_TYPE" == "null" ]] && { log_error "zone.network_type is required"; ((errors++)); }
    
    [[ -z "$PHYSICAL_NETWORK_NAME" || "$PHYSICAL_NETWORK_NAME" == "null" ]] && { log_error "physical_network.name is required"; ((errors++)); }
    [[ -z "$ISOLATION_METHOD" || "$ISOLATION_METHOD" == "null" ]] && { log_error "physical_network.isolation_method is required"; ((errors++)); }
    
    [[ -z "$PUBLIC_START_IP" || "$PUBLIC_START_IP" == "null" ]] && { log_error "public_ip_range.start_ip is required"; ((errors++)); }
    [[ -z "$PUBLIC_END_IP" || "$PUBLIC_END_IP" == "null" ]] && { log_error "public_ip_range.end_ip is required"; ((errors++)); }
    [[ -z "$PUBLIC_GATEWAY" || "$PUBLIC_GATEWAY" == "null" ]] && { log_error "public_ip_range.gateway is required"; ((errors++)); }
    [[ -z "$PUBLIC_NETMASK" || "$PUBLIC_NETMASK" == "null" ]] && { log_error "public_ip_range.netmask is required"; ((errors++)); }
    
    [[ -z "$POD_NAME" || "$POD_NAME" == "null" ]] && { log_error "pod.name is required"; ((errors++)); }
    [[ -z "$POD_GATEWAY" || "$POD_GATEWAY" == "null" ]] && { log_error "pod.gateway is required"; ((errors++)); }
    
    [[ -z "$CLUSTER_NAME" || "$CLUSTER_NAME" == "null" ]] && { log_error "cluster.name is required"; ((errors++)); }
    [[ -z "$CLUSTER_HYPERVISOR" || "$CLUSTER_HYPERVISOR" == "null" ]] && { log_error "cluster.hypervisor is required"; ((errors++)); }
    
    [[ ${#HOST_NAMES[@]} -eq 0 ]] && { log_error "At least one host is required"; ((errors++)); }
    
    [[ -z "$PRIMARY_STORAGE_NAME" || "$PRIMARY_STORAGE_NAME" == "null" ]] && { log_error "primary_storage.name is required"; ((errors++)); }
    [[ -z "$PRIMARY_STORAGE_SERVER" || "$PRIMARY_STORAGE_SERVER" == "null" ]] && { log_error "primary_storage.server is required"; ((errors++)); }
    
    [[ -z "$SECONDARY_STORAGE_NAME" || "$SECONDARY_STORAGE_NAME" == "null" ]] && { log_error "secondary_storage.name is required"; ((errors++)); }
    [[ -z "$SECONDARY_STORAGE_SERVER" || "$SECONDARY_STORAGE_SERVER" == "null" ]] && { log_error "secondary_storage.server is required"; ((errors++)); }
    
    # Check for empty host passwords
    for ((i=0; i<${#HOST_NAMES[@]}; i++)); do
        if [[ -z "${HOST_PASSWORDS[$i]}" || "${HOST_PASSWORDS[$i]}" == "null" ]]; then
            log_error "Password required for host: ${HOST_NAMES[$i]}"
            ((errors++))
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        log_error "Configuration validation failed with $errors error(s)"
        echo ""
        echo "Please check your configuration file: $CONFIG_FILE"
        echo "Refer to zone-config.yml.example for the correct format"
        exit 1
    fi
    
    log_info "✓ Configuration validated successfully"
}

configure_cloudmonkey() {
    log_step "Configuring CloudMonkey API credentials..."
    
    # Configure CloudMonkey
    cmk set profile local
    cmk set url "$CLOUDSTACK_URL"
    cmk set apikey "$CLOUDSTACK_API_KEY"
    cmk set secretkey "$CLOUDSTACK_SECRET_KEY"
    cmk set display json
    cmk set output json
    cmk sync
    
    log_info "CloudMonkey configured successfully"
}

# Helper function to get ID from name
get_zone_id() {
    cmk list zones name="$1" filter=id | jq -r '.zone[]?.id // empty' | head -n 1
}

get_physical_network_id() {
    cmk list physicalnetworks name="$1" filter=id | jq -r '.physicalnetwork[]?.id // empty' | head -n 1
}

get_pod_id() {
    cmk list pods name="$1" filter=id | jq -r '.pod[]?.id // empty' | head -n 1
}

get_cluster_id() {
    cmk list clusters name="$1" filter=id | jq -r '.cluster[]?.id // empty' | head -n 1
}

create_zone() {
    log_step "Creating Zone: $ZONE_NAME"
    
    local existing_zone_id=$(get_zone_id "$ZONE_NAME")
    
    if [[ -n "$existing_zone_id" ]]; then
        log_warn "Zone '$ZONE_NAME' already exists (ID: $existing_zone_id)"
        ZONE_ID="$existing_zone_id"
        return 0
    fi
    
    local result=$(cmk create zone \
        name="$ZONE_NAME" \
        dns1="$ZONE_DNS1" \
        dns2="$ZONE_DNS2" \
        internaldns1="$ZONE_INTERNAL_DNS1" \
        internaldns2="$ZONE_INTERNAL_DNS2" \
        networktype="$ZONE_NETWORK_TYPE" \
        guestcidraddress="$ZONE_GUEST_CIDR" \
        filter=id | jq -r '.zone.id // empty')
    
    ZONE_ID="$result"
    log_info "Zone created with ID: $ZONE_ID"
}

create_physical_network() {
    log_step "Creating Physical Network: $PHYSICAL_NETWORK_NAME"
    
    local existing_network_id=$(get_physical_network_id "$PHYSICAL_NETWORK_NAME")
    
    if [[ -n "$existing_network_id" ]]; then
        log_warn "Physical Network '$PHYSICAL_NETWORK_NAME' already exists (ID: $existing_network_id)"
        PHYSICAL_NETWORK_ID="$existing_network_id"
        return 0
    fi
    
    local result=$(cmk create physicalnetwork \
        name="$PHYSICAL_NETWORK_NAME" \
        zoneid="$ZONE_ID" \
        isolationmethods="$ISOLATION_METHOD" \
        vlan="$VLAN_RANGE" \
        filter=id | jq -r '.physicalnetwork.id // empty')
    
    PHYSICAL_NETWORK_ID="$result"
    log_info "Physical Network created with ID: $PHYSICAL_NETWORK_ID"
}

add_traffic_types() {
    log_step "Adding Traffic Types..."
    
    # Management Traffic
    log_info "Adding Management traffic type..."
    cmk add traffictype physicalnetworkid="$PHYSICAL_NETWORK_ID" traffictype=Management kvmnetworklabel="$MANAGEMENT_LABEL" 2>&1 | grep -v "already exists" || true
    
    # Guest Traffic
    log_info "Adding Guest traffic type..."
    cmk add traffictype physicalnetworkid="$PHYSICAL_NETWORK_ID" traffictype=Guest kvmnetworklabel="$GUEST_LABEL" 2>&1 | grep -v "already exists" || true
    
    # Public Traffic
    log_info "Adding Public traffic type..."
    cmk add traffictype physicalnetworkid="$PHYSICAL_NETWORK_ID" traffictype=Public kvmnetworklabel="$PUBLIC_LABEL" 2>&1 | grep -v "already exists" || true
    
    # Storage Traffic
    log_info "Adding Storage traffic type..."
    cmk add traffictype physicalnetworkid="$PHYSICAL_NETWORK_ID" traffictype=Storage kvmnetworklabel="$STORAGE_LABEL" 2>&1 | grep -v "already exists" || true
    
    log_info "Traffic types configured"
}

enable_network_service_providers() {
    log_step "Enabling Network Service Providers..."
    
    # List all network service providers for this physical network
    log_info "Querying network service providers for physical network: $PHYSICAL_NETWORK_ID"
    
    # Get VirtualRouter provider ID
    local vr_provider_id=$(cmk list networkserviceproviders name=VirtualRouter physicalnetworkid="$PHYSICAL_NETWORK_ID" filter=id | jq -r '.networkserviceprovider[]?.id // empty' | head -n 1)
    
    if [[ -n "$vr_provider_id" ]]; then
        log_info "Found VirtualRouter provider (ID: $vr_provider_id)"
        log_info "Enabling VirtualRouter Network Service Provider..."
        
        # Enable the VirtualRouter provider
        local result=$(cmk update networkserviceprovider id="$vr_provider_id" state=Enabled 2>&1)
        if echo "$result" | grep -qi "error"; then
            log_warn "VirtualRouter may already be enabled or error occurred"
        else
            log_info "✓ VirtualRouter provider enabled"
        fi
        
        # Configure VirtualRouter element
        log_info "Configuring VirtualRouter element..."
        local vr_element_id=$(cmk list virtualrouterelements nspid="$vr_provider_id" filter=id | jq -r '.virtualrouterelement[]?.id // empty' | head -n 1)
        if [[ -n "$vr_element_id" ]]; then
            log_info "Found VirtualRouter element (ID: $vr_element_id)"
            cmk configure virtualrouterelement id="$vr_element_id" enabled=true 2>&1 | grep -v "already" || true
            log_info "✓ VirtualRouter element configured"
        fi
    else
        log_error "VirtualRouter provider not found for physical network"
        return 1
    fi
    
    # Get SecurityGroupProvider ID
    local sg_provider_id=$(cmk list networkserviceproviders name=SecurityGroupProvider physicalnetworkid="$PHYSICAL_NETWORK_ID" filter=id | jq -r '.networkserviceprovider[]?.id // empty' | head -n 1)
    
    if [[ -n "$sg_provider_id" ]]; then
        log_info "Found SecurityGroupProvider (ID: $sg_provider_id)"
        log_info "Enabling SecurityGroupProvider..."
        cmk update networkserviceprovider id="$sg_provider_id" state=Enabled 2>&1 | grep -v "already" || true
        log_info "✓ SecurityGroupProvider enabled"
    fi
    
    # Get VpcVirtualRouter provider ID (for Advanced networking)
    local vpcvr_provider_id=$(cmk list networkserviceproviders name=VpcVirtualRouter physicalnetworkid="$PHYSICAL_NETWORK_ID" filter=id | jq -r '.networkserviceprovider[]?.id // empty' | head -n 1)
    
    if [[ -n "$vpcvr_provider_id" ]]; then
        log_info "Found VpcVirtualRouter provider (ID: $vpcvr_provider_id)"
        log_info "Enabling VpcVirtualRouter..."
        cmk update networkserviceprovider id="$vpcvr_provider_id" state=Enabled 2>&1 | grep -v "already" || true
        
        # Configure VPC VR element
        local vpcvr_element_id=$(cmk list virtualrouterelements nspid="$vpcvr_provider_id" filter=id | jq -r '.virtualrouterelement[]?.id // empty' | head -n 1)
        if [[ -n "$vpcvr_element_id" ]]; then
            log_info "Found VpcVirtualRouter element (ID: $vpcvr_element_id)"
            cmk configure virtualrouterelement id="$vpcvr_element_id" enabled=true 2>&1 | grep -v "already" || true
            log_info "✓ VpcVirtualRouter element configured"
        fi
    fi
    
    log_info "✓ All network service providers configured successfully"
}

enable_physical_network() {
    log_step "Enabling Physical Network..."
    
    cmk update physicalnetwork id="$PHYSICAL_NETWORK_ID" state=Enabled 2>&1 | grep -v "already enabled" || true
    
    log_info "Physical Network enabled"
}

add_public_ip_range() {
    log_step "Adding Public IP Range..."
    
    # Check if IP range already exists
    local existing_range=$(cmk list vlanipranges zoneid="$ZONE_ID" forvirtualnetwork=true | grep -w "$PUBLIC_START_IP" || true)
    
    if [[ -n "$existing_range" ]]; then
        log_warn "Public IP range $PUBLIC_START_IP-$PUBLIC_END_IP already exists"
        return 0
    fi
    
    cmk create vlaniprange \
        zoneid="$ZONE_ID" \
        physicalnetworkid="$PHYSICAL_NETWORK_ID" \
        startip="$PUBLIC_START_IP" \
        endip="$PUBLIC_END_IP" \
        gateway="$PUBLIC_GATEWAY" \
        netmask="$PUBLIC_NETMASK" \
        vlan="$PUBLIC_VLAN" \
        forvirtualnetwork=true
    
    log_info "Public IP range added: $PUBLIC_START_IP - $PUBLIC_END_IP"
}

create_pod() {
    log_step "Creating Pod: $POD_NAME"
    
    local existing_pod_id=$(get_pod_id "$POD_NAME")
    
    if [[ -n "$existing_pod_id" ]]; then
        log_warn "Pod '$POD_NAME' already exists (ID: $existing_pod_id)"
        POD_ID="$existing_pod_id"
        return 0
    fi
    
    local result=$(cmk create pod \
        name="$POD_NAME" \
        zoneid="$ZONE_ID" \
        gateway="$POD_GATEWAY" \
        netmask="$POD_NETMASK" \
        startip="$POD_START_IP" \
        endip="$POD_END_IP" \
        filter=id | jq -r '.pod.id // empty')
    
    POD_ID="$result"
    log_info "Pod created with ID: $POD_ID"
}

create_cluster() {
    log_step "Creating Cluster: $CLUSTER_NAME"
    
    local existing_cluster_id=$(get_cluster_id "$CLUSTER_NAME")
    
    if [[ -n "$existing_cluster_id" ]]; then
        log_warn "Cluster '$CLUSTER_NAME' already exists (ID: $existing_cluster_id)"
        CLUSTER_ID="$existing_cluster_id"
        return 0
    fi
    
    local result=$(cmk add cluster \
        clustername="$CLUSTER_NAME" \
        zoneid="$ZONE_ID" \
        podid="$POD_ID" \
        hypervisor="$CLUSTER_HYPERVISOR" \
        clustertype="$CLUSTER_TYPE" \
        filter=id | jq -r '.cluster[]?.id // empty' | head -n 1)
    
    CLUSTER_ID="$result"
    log_info "Cluster created with ID: $CLUSTER_ID"
}

add_hosts() {
    log_step "Adding KVM Hosts..."
    
    for i in "${!HOST_NAMES[@]}"; do
        local host_name="${HOST_NAMES[$i]}"
        local host_ip="${HOST_IPS[$i]}"
        local host_username="${HOST_USERNAMES[$i]}"
        local host_password="${HOST_PASSWORDS[$i]}"
        
        log_info "Adding host: $host_name ($host_ip)..."
        
        # Check if host already exists
        local existing_host=$(cmk list hosts zoneid="$ZONE_ID" name="$host_name" 2>&1 || true)
        if echo "$existing_host" | grep -q "$host_ip"; then
            log_warn "Host $host_name already exists"
            continue
        fi
        
        cmk add host \
            zoneid="$ZONE_ID" \
            podid="$POD_ID" \
            clusterid="$CLUSTER_ID" \
            hypervisor="$CLUSTER_HYPERVISOR" \
            url="http://$host_ip" \
            username="$host_username" \
            password="$host_password" \
            hosttags="" 2>&1 | grep -v "already in the database" || true
        
        log_info "Host $host_name added successfully"
    done
}

add_primary_storage() {
    log_step "Adding Primary Storage: $PRIMARY_STORAGE_NAME"
    
    # Check if storage already exists
    local existing_storage=$(cmk list storagepools name="$PRIMARY_STORAGE_NAME" 2>&1 || true)
    if echo "$existing_storage" | grep -q "$PRIMARY_STORAGE_NAME"; then
        log_warn "Primary Storage '$PRIMARY_STORAGE_NAME' already exists"
        return 0
    fi
    
    cmk create storagepool \
        name="$PRIMARY_STORAGE_NAME" \
        zoneid="$ZONE_ID" \
        podid="$POD_ID" \
        clusterid="$CLUSTER_ID" \
        url="nfs://$PRIMARY_STORAGE_SERVER$PRIMARY_STORAGE_PATH" \
        scope="$PRIMARY_STORAGE_SCOPE"
    
    log_info "Primary Storage added: $PRIMARY_STORAGE_NAME"
}

add_secondary_storage() {
    log_step "Adding Secondary Storage: $SECONDARY_STORAGE_NAME"
    
    # Check if storage already exists
    local existing_storage=$(cmk list imagestores name="$SECONDARY_STORAGE_NAME" 2>&1 || true)
    if echo "$existing_storage" | grep -q "$SECONDARY_STORAGE_NAME"; then
        log_warn "Secondary Storage '$SECONDARY_STORAGE_NAME' already exists"
        return 0
    fi
    
    cmk add imagestore \
        name="$SECONDARY_STORAGE_NAME" \
        provider="$SECONDARY_STORAGE_PROVIDER" \
        zoneid="$ZONE_ID" \
        url="nfs://$SECONDARY_STORAGE_SERVER$SECONDARY_STORAGE_PATH"
    
    log_info "Secondary Storage added: $SECONDARY_STORAGE_NAME"
}

enable_zone() {
    log_step "Enabling Zone: $ZONE_NAME"
    
    cmk update zone id="$ZONE_ID" allocationstate=Enabled 2>&1 | grep -v "already" || true
    
    log_info "Zone enabled successfully"
}

verify_setup() {
    log_step "Verifying Setup..."
    
    echo ""
    log_info "Zone Information:"
    cmk list zones name="$ZONE_NAME"
    
    echo ""
    log_info "Physical Networks:"
    cmk list physicalnetworks zoneid="$ZONE_ID"
    
    echo ""
    log_info "Pods:"
    cmk list pods zoneid="$ZONE_ID"
    
    echo ""
    log_info "Clusters:"
    cmk list clusters zoneid="$ZONE_ID"
    
    echo ""
    log_info "Hosts:"
    cmk list hosts zoneid="$ZONE_ID"
    
    echo ""
    log_info "Primary Storage:"
    cmk list storagepools zoneid="$ZONE_ID"
    
    echo ""
    log_info "Secondary Storage:"
    cmk list imagestores zoneid="$ZONE_ID"
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              Zone Setup Complete!                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Zone Information:"
    echo "  - Zone Name: $ZONE_NAME"
    echo "  - Zone ID: $ZONE_ID"
    echo "  - Network Type: $ZONE_NETWORK_TYPE"
    echo "  - Web UI: ${CLOUDSTACK_URL/\/client\/api/\/client}"
    echo ""
    echo "Next Steps:"
    echo "  1. Check System VMs status:"
    echo "     cmk list systemvms zoneid=$ZONE_ID"
    echo ""
    echo "  2. Wait for System VMs to be Running (may take 5-10 minutes)"
    echo ""
    echo "  3. Register templates and create instances"
    echo ""
}

# Main execution
main() {
    # Get config file from argument
    CONFIG_FILE="$1"
    
    # Check for help flag
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    print_header
    check_config_file
    check_dependencies
    load_yaml_config
    validate_config
    configure_cloudmonkey
    
    # Zone Setup Sequence
    create_zone
    create_physical_network
    add_traffic_types
    enable_network_service_providers
    enable_physical_network
    add_public_ip_range
    create_pod
    create_cluster
    add_hosts
    add_primary_storage
    add_secondary_storage
    enable_zone
    
    verify_setup
    print_summary
}

# Execute main function
main "$@"
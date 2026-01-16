#!/bin/bash
# SystemVM Template Reinstall Script
# This script reinstalls the SystemVM template for CloudStack

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
    echo "║         CloudStack SystemVM Template Reinstaller           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

# Configuration
NFS_SERVER="${NFS_SERVER:-10.10.0.116}"
SECONDARY_STORAGE_MOUNT="${SECONDARY_STORAGE_MOUNT:-/mnt/secondary}"
SECONDARY_STORAGE_PATH="${NFS_SERVER}:/export/secondary"
TEMPLATE_DIR="${SECONDARY_STORAGE_MOUNT}/template/tmpl/1/3"
SYSTEMVM_TEMPLATE_URL="${SYSTEMVM_TEMPLATE_URL:-http://download.cloudstack.org/systemvm/4.19/systemvmtemplate-4.19.1-kvm.qcow2.bz2}"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

confirm_reinstall() {
    echo ""
    log_warn "이 작업은 기존 SystemVM 템플릿을 삭제하고 재설치합니다."
    log_warn "진행 중인 VM 배포가 중단될 수 있습니다."
    echo ""
    read -p "계속하시겠습니까? (yes/no): " response
    
    if [[ "$response" != "yes" ]]; then
        log_info "작업이 취소되었습니다."
        exit 0
    fi
}

prompt_mysql_password() {
    echo ""
    read -s -p "MySQL root password: " MYSQL_ROOT_PASSWORD
    echo ""
    
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        log_error "MySQL root password is required"
        exit 1
    fi
}

check_secondary_storage_mounted() {
    log_info "Checking secondary storage mount..."
    
    if mountpoint -q "$SECONDARY_STORAGE_MOUNT"; then
        log_info "Secondary storage is already mounted"
        return 0
    else
        log_warn "Secondary storage is not mounted"
        return 1
    fi
}

mount_secondary_storage() {
    log_info "Mounting secondary storage..."
    
    # Create mount point if not exists
    if [[ ! -d "$SECONDARY_STORAGE_MOUNT" ]]; then
        mkdir -p "$SECONDARY_STORAGE_MOUNT"
        log_info "Created mount point: $SECONDARY_STORAGE_MOUNT"
    fi
    
    # Mount NFS
    if ! mount -t nfs -o defaults "$SECONDARY_STORAGE_PATH" "$SECONDARY_STORAGE_MOUNT"; then
        log_error "Failed to mount secondary storage"
        exit 1
    fi
    
    log_info "Secondary storage mounted successfully"
}

remove_existing_template() {
    log_info "Removing existing template directory..."
    
    if [[ -d "$TEMPLATE_DIR" ]]; then
        rm -rf "$TEMPLATE_DIR"
        log_info "Existing template removed: $TEMPLATE_DIR"
    else
        log_info "No existing template found"
    fi
}

install_systemvm_template() {
    log_info "Installing SystemVM template..."
    log_info "Template URL: $SYSTEMVM_TEMPLATE_URL"
    echo ""
    
    if [[ ! -f /usr/share/cloudstack-common/scripts/storage/secondary/cloud-install-sys-tmplt ]]; then
        log_error "CloudStack installation script not found"
        log_error "Please ensure CloudStack is properly installed"
        exit 1
    fi
    
    # Run installation script
    /usr/share/cloudstack-common/scripts/storage/secondary/cloud-install-sys-tmplt \
        -m "$SECONDARY_STORAGE_MOUNT" \
        -u "$SYSTEMVM_TEMPLATE_URL" \
        -h kvm \
        -s "$MYSQL_ROOT_PASSWORD" \
        -t 3 \
        -F
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Template installation failed with exit code: $exit_code"
        exit 1
    fi
    
    log_info "Template installation completed"
}

verify_template() {
    log_info "Verifying template installation..."
    
    if [[ -d "$TEMPLATE_DIR" ]]; then
        log_info "✓ Template directory exists: $TEMPLATE_DIR"
        
        # Check for template files
        local file_count=$(find "$TEMPLATE_DIR" -type f | wc -l)
        log_info "✓ Found $file_count file(s) in template directory"
        
        if [[ $file_count -gt 0 ]]; then
            log_info "Template installation verified successfully"
            return 0
        else
            log_error "Template directory exists but no files found"
            return 1
        fi
    else
        log_error "✗ Template directory not found: $TEMPLATE_DIR"
        return 1
    fi
}

restart_management_service() {
    echo ""
    read -p "CloudStack Management 서비스를 재시작하시겠습니까? (y/n): " response
    
    if [[ "$response" == "y" ]]; then
        log_info "Restarting CloudStack Management service..."
        
        if systemctl restart cloudstack-management; then
            log_info "CloudStack Management service restarted successfully"
        else
            log_error "Failed to restart CloudStack Management service"
            return 1
        fi
    else
        log_info "Skipping service restart"
    fi
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              Installation Complete!                        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Summary:"
    echo "  - NFS Server: $NFS_SERVER"
    echo "  - Mount Point: $SECONDARY_STORAGE_MOUNT"
    echo "  - Template Directory: $TEMPLATE_DIR"
    echo "  - Template URL: $SYSTEMVM_TEMPLATE_URL"
    echo ""
    echo "Next steps:"
    echo "  1. Verify SystemVM template in CloudStack UI"
    echo "  2. Destroy and recreate System VMs if needed:"
    echo "     - Console Proxy VM"
    echo "     - Secondary Storage VM"
    echo ""
}

# Main execution
main() {
    print_header
    check_root
    confirm_reinstall
    prompt_mysql_password
    
    if ! check_secondary_storage_mounted; then
        mount_secondary_storage
    fi
    
    remove_existing_template
    install_systemvm_template
    
    if verify_template; then
        restart_management_service
        print_summary
    else
        log_error "Template verification failed"
        exit 1
    fi
}

# Allow environment variable overrides
if [[ -f ~/.cloudstack-config ]]; then
    source ~/.cloudstack-config
fi

main "$@"

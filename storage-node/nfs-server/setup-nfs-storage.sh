#!/bin/bash
# CloudStack NFS Storage Server Setup Script
# Tested on Ubuntu 22.04 with CloudStack 4.19.2.0
#
# Usage: sudo ./install-nfs-server.sh [storage_device]
# Example: sudo ./install-nfs-server.sh /dev/sdb

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STORAGE_DEVICE="${1:-/dev/sdb}"
EXPORT_PATH="/export"
PRIMARY_PATH="/export/primary"
SECONDARY_PATH="/export/secondary"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

confirm_action() {
    local message="$1"
    echo -e "${YELLOW}${message}${NC}"
    read -p "Continue? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        log_warn "Operation cancelled"
        exit 0
    fi
}

check_storage_device() {
    if [[ ! -b "$STORAGE_DEVICE" ]]; then
        log_error "Storage device $STORAGE_DEVICE not found!"
        log_info "Available block devices:"
        lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT
        exit 1
    fi
    
    log_info "Storage device: $STORAGE_DEVICE"
    lsblk "$STORAGE_DEVICE"
    
    confirm_action "⚠️  WARNING: This will format $STORAGE_DEVICE and all data will be lost!"
}

partition_disk() {
    log_info "Partitioning disk $STORAGE_DEVICE..."
    
    if [[ -b "${STORAGE_DEVICE}1" ]]; then
        log_warn "Partition ${STORAGE_DEVICE}1 already exists, skipping partitioning"
        return
    fi
    
    # Create partition using parted (more reliable than fdisk in scripts)
    parted -s "$STORAGE_DEVICE" mklabel gpt
    parted -s "$STORAGE_DEVICE" mkpart primary ext4 0% 100%
    
    # Wait for partition to be available
    sleep 2
    partprobe "$STORAGE_DEVICE"
    sleep 2
    
    log_info "Partition created: ${STORAGE_DEVICE}1"
}

format_disk() {
    log_info "Formatting ${STORAGE_DEVICE}1 with ext4..."
    
    # Check if already formatted
    if blkid "${STORAGE_DEVICE}1" | grep -q "ext4"; then
        log_warn "Partition is already formatted as ext4, skipping format"
        return
    fi
    
    mkfs.ext4 -F "${STORAGE_DEVICE}1"
    log_info "Format completed"
}

mount_disk() {
    log_info "Creating mount point $EXPORT_PATH..."
    mkdir -p "$EXPORT_PATH"
    
    # Check if already mounted
    if mountpoint -q "$EXPORT_PATH"; then
        log_warn "$EXPORT_PATH is already mounted"
        return
    fi
    
    log_info "Mounting ${STORAGE_DEVICE}1 to $EXPORT_PATH..."
    mount "${STORAGE_DEVICE}1" "$EXPORT_PATH"
    
    # Add to fstab if not already present
    if ! grep -q "${STORAGE_DEVICE}1" /etc/fstab; then
        log_info "Adding mount to /etc/fstab..."
        echo "${STORAGE_DEVICE}1 $EXPORT_PATH ext4 defaults 0 0" >> /etc/fstab
    fi
    
    log_info "Mount completed"
}

set_permissions() {
    log_info "Setting permissions on $EXPORT_PATH..."
    chown -R nobody:nogroup "$EXPORT_PATH"
    chmod 777 "$EXPORT_PATH"
}

install_nfs() {
    log_info "Installing NFS server packages..."
    apt-get update -y
    apt-get install -y nfs-kernel-server quota
    log_info "NFS packages installed"
}

create_export_directories() {
    log_info "Creating NFS export directories..."
    mkdir -p "$PRIMARY_PATH"
    mkdir -p "$SECONDARY_PATH"
    chown -R nobody:nogroup "$PRIMARY_PATH" "$SECONDARY_PATH"
    chmod 777 "$PRIMARY_PATH" "$SECONDARY_PATH"
    log_info "Export directories created"
}

configure_nfs_exports() {
    log_info "Configuring NFS exports..."
    
    # Backup existing exports
    if [[ -f /etc/exports ]]; then
        cp /etc/exports /etc/exports.backup.$(date +%Y%m%d-%H%M%S)
    fi
    
    # Add export if not already present
    if ! grep -q "^$EXPORT_PATH" /etc/exports; then
        echo "$EXPORT_PATH *(rw,async,no_root_squash,no_subtree_check)" >> /etc/exports
        log_info "Added $EXPORT_PATH to /etc/exports"
    else
        log_warn "Export already exists in /etc/exports"
    fi
    
    exportfs -a
    log_info "NFS exports configured"
}

configure_nfs_ports() {
    log_info "Configuring NFS fixed ports..."
    
    # Backup configuration files
    for file in /etc/default/nfs-kernel-server /etc/default/nfs-common /etc/default/quota; do
        if [[ -f "$file" ]]; then
            cp "$file" "${file}.backup.$(date +%Y%m%d-%H%M%S)"
        fi
    done
    
    # Configure NFS mount daemon
    sed -i -e 's/^RPCMOUNTDOPTS="--manage-gids"$/RPCMOUNTDOPTS="-p 892 --manage-gids"/g' /etc/default/nfs-kernel-server
    
    # Configure statd
    sed -i -e 's/^STATDOPTS=$/STATDOPTS="--port 662 --outgoing-port 2020"/g' /etc/default/nfs-common
    
    if ! grep -q "^NEED_STATD=yes" /etc/default/nfs-common; then
        echo "NEED_STATD=yes" >> /etc/default/nfs-common
    fi
    
    # Configure quota daemon
    sed -i -e 's/^RPCRQUOTADOPTS=$/RPCRQUOTADOPTS="-p 875"/g' /etc/default/quota
    
    log_info "NFS ports configured"
}

restart_nfs() {
    log_info "Restarting NFS server..."
    systemctl restart nfs-kernel-server
    systemctl enable nfs-kernel-server
    log_info "NFS server restarted and enabled"
}

verify_installation() {
    log_info "Verifying installation..."
    
    echo ""
    echo "=== Storage Mount Status ==="
    df -h "$EXPORT_PATH"
    
    echo ""
    echo "=== NFS Exports ==="
    exportfs -v
    
    echo ""
    echo "=== NFS Server Status ==="
    systemctl status nfs-kernel-server --no-pager
    
    echo ""
    echo "=== Directory Structure ==="
    ls -la "$EXPORT_PATH"
    
    echo ""
    log_info "You can test NFS from another machine using:"
    log_info "  showmount -e $(hostname -I | awk '{print $1}')"
}

print_summary() {
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         NFS Storage Server Setup Complete!                ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  Server IP: $server_ip"
    echo "║  Export Path: $EXPORT_PATH"
    echo "║  Primary Storage: $PRIMARY_PATH"
    echo "║  Secondary Storage: $SECONDARY_PATH"
    echo "║"
    echo "║  NFS is now ready for CloudStack!"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "1. Test NFS from Management server:"
    echo "   showmount -e $server_ip"
    echo "2. Mount on Management server:"
    echo "   mount -t nfs $server_ip:$EXPORT_PATH /mnt/test"
    echo ""
}

# Main execution
main() {
    log_info "Starting CloudStack NFS Storage Server setup..."
    
    check_root
    
    if [[ "$STORAGE_DEVICE" != "/dev/sdb" ]]; then
        log_info "Using custom storage device: $STORAGE_DEVICE"
    fi
    
    # Disk setup
    check_storage_device
    partition_disk
    format_disk
    mount_disk
    set_permissions
    
    # NFS setup
    install_nfs
    create_export_directories
    configure_nfs_exports
    configure_nfs_ports
    restart_nfs
    
    # Verification
    verify_installation
    print_summary
    
    log_info "Setup completed successfully!"
}

# Run main function
main "$@"

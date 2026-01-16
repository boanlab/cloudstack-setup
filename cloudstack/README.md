# CloudStack Ansible Automation

Ansible project for automated deployment of CloudStack 4.19 infrastructure.

## Quick Start

```bash
# 0. Prepare Ansible Controller
./setup-ansible-controller.sh

# 1. Configure inventory
cp inventory/hosts.example inventory/hosts
vi inventory/hosts

# 2. Configure network and passwords
vi inventory/group_vars/all/all.yml
vi inventory/group_vars/all/vault.yml
vi inventory/group_vars/management/management.yml

# 3. Copy SSH keys to all nodes
./copy-ssh-keys.sh

# 4. Execute deployment
ansible-playbook -i inventory/hosts playbooks/site.yml
```

> **Detailed Installation Guide**: [../docs/installation.md](../docs/installation.md)

## Playbook List

| Playbook | Description |
|----------|-------------|
| `site.yml` | Complete automated installation (combines steps 00~04) |
| `00-setup-network.yml` | Configure network bridges |
| `01-prepare-common.yml` | Common preparation (NTP, packages, etc.) |
| `02-setup-database.yml` | Install MySQL Database |
| `03-setup-management.yml` | Install Management Server |
| `04-setup-kvm-hosts.yml` | Install KVM Hypervisor |

## Inventory Structure

```
inventory/
├── hosts                          # Server IP address definitions
├── hosts.example                  # Example file
└── group_vars/
    ├── all/
    │   ├── all.yml               # Common settings (network CIDR, versions, etc.)
    │   └── vault.yml             # Passwords (encryption recommended)
    ├── management/
    │   └── management.yml        # Management Server configuration (NFS info)
    ├── database/
    │   └── database.yml          # Database configuration
    └── kvm-hosts/
        └── kvm-hosts.yml         # KVM Host configuration
```

## Ansible Commands

### Connection Test

```bash
# Ping test all nodes
ansible all -i inventory/hosts -m ping

# Test specific group only
ansible management -i inventory/hosts -m ping
ansible kvm-hosts -i inventory/hosts -m ping
```

### Execute Ad-hoc Commands

```bash
# Check service status
ansible management -i inventory/hosts -m shell -a "systemctl status cloudstack-management"

# Check disk usage
ansible all -i inventory/hosts -m shell -a "df -h"
```

## Configuration Options

For all configurable options and detailed descriptions, see [OPTIONS.md](OPTIONS.md).

## References

- Detailed Installation Guide: [../docs/installation.md](../docs/installation.md)
- Troubleshooting: [../docs/troubleshooting.md](../docs/troubleshooting.md)
- CloudStack Official Documentation: https://docs.cloudstack.apache.org/

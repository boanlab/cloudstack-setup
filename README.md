# CloudStack Infrastructure Automation

A comprehensive infrastructure automation project for fully automated deployment of Apache CloudStack 4.19.

Manage entire CloudStack infrastructure as code using Ansible automation - from Management Server, Database, KVM Hypervisor, NFS Storage, to Advanced Zone configuration.

**Tested Environment**: Ubuntu 24.04, CloudStack 4.19.2.0


## Directory Structure

```
cloudstack-infra/
├── cloudstack/                    # Main Ansible automation directory
│   ├── inventory/                 # Inventory and variables
│   │   ├── hosts                  # Host definitions (management, database, kvm-hosts)
│   │   └── group_vars/            # Group variables
│   │
│   ├── playbooks/                 # Ansible playbooks
│   │
│   ├── roles/                     # Ansible roles
│   │   ├── common/                # Common setup (NTP, apt lock handling)
│   │   ├── database/              # MySQL 8.0 installation and optimization
│   │   ├── management/            # CloudStack Management + Usage Server
│   │   └── kvm-host/              # KVM + LibvirtD + Agent setup
│   │
│   ├── README.md                  # CloudStack Ansible documentation
│   ├── INSTALL.md                 # Detailed installation guide
│   └── ansible.cfg                # Ansible configuration
│
├── storage-node/                  # Standalone NFS Storage installation
│   └── nfs-server/
│       └── setup-nfs-storage.sh   # NFS server automated installation script
│
├── mgmt-node/                     # Management node utilities
│   ├── install-cloudmonkey.sh     # CloudMonkey CLI installation
│   └── nfs-server/                # NFS registration scripts
│       ├── register-primary-storage.sh
│       └── register-secondary-storage.sh
│
└── README.md                      # This file
```

## Quick Start

### Prerequisites

- **Ansible 2.9+** (Control Node)
- **Ubuntu 24.04** (Target servers)
- **Minimum 3 servers**: Management, KVM Host, NFS Storage (can be consolidated)
- **2 separate networks**: Public, Management 
- **SSH access** and **sudo privileges**: NOPASSWD configuration required

### Step 1: Clone Repository

```bash
git clone https://github.com/boanlab/cloudstack-infra.git
cd cloudstack-infra/cloudstack
```

### Step 2: Configure Inventory

```bash
# Edit inventory file
vi inventory/hosts
```

Enter your actual server IP addresses:
```ini
[management]
mgmt-server ansible_host=10.15.0.113

[database]
db-server ansible_host=10.15.0.113

[kvm-hosts]
kvm-host-01 ansible_host=10.15.0.114
```

### Step 3: Configure Variables

#### 3-1. Vault (Passwords)

```bash
vi inventory/group_vars/vault.yml
```

```yaml
vault_mysql_root_password: "your_secure_password"
vault_cloudstack_db_password: "your_secure_password"
vault_kvm_host_password: "your_ssh_password"
```

#### 3-2. Zone Configuration

```bash
vi inventory/group_vars/zone.yml
```

Key configurations:
- `zone_name`: Zone name
- `cloudstack_physical_networks`: Physical Network and Traffic Types
- `cloudstack_public_ip_ranges`: Public IP ranges (for System VMs)
- `cloudstack_pods`: Pod IP ranges
- `cloudstack_clusters`: Cluster definitions
- `cloudstack_hosts`: KVM Host list
- `cloudstack_primary_storages`: Primary Storage (NFS)
- `cloudstack_secondary_storages`: Secondary Storage (NFS)

### Step 4: Install NFS Storage (Separate Server)

NFS Storage is installed separately using a standalone script:

```bash
# Run on NFS server
cd storage-node/nfs-server
sudo ./setup-nfs-storage.sh -d /dev/sdb -y
```

### Step 5: Deploy CloudStack Infrastructure

```bash
cd cloudstack
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-pass --ask-become-pass
```

**Execution order:**
1. Network bridge setup (cloudbr0, cloudbr1)
2. Common packages installation (NTP, basic utilities)
3. MySQL installation and configuration
4. Management Server installation and initialization
5. KVM Hypervisor setup

### Step 6: Automated Zone Configuration

After Management Server installation, generate API Key from Web UI:

1. Access http://<management-node-ip>:8080/client
2. Login with admin / password
3. Navigate to Accounts → admin → View Users → admin → Keys
4. Click Generate Keys
5. Enter API Key in `inventory/group_vars/zone.yml`

Run automated zone configuration:

```bash
ansible-playbook -i inventory/hosts playbooks/05-setup-zone.yml --ask-pass
```

**Automatically created:**
- Advanced Zone creation
- Physical Network + Traffic Types (Management, Storage, Public, Guest)
- VXLAN VNI range configuration (5000-6000)
- Public IP Range addition
- Pod, Cluster, Host addition
- Primary/Secondary Storage registration

### Step 7: Access Verification

```bash
# Web UI access
http://10.15.0.113:8080/client

# Default credentials
Username: admin
Password: password
```

## Network Architecture

### Two Independent Networks

#### CloudStack Public Network (cloudbr0)
- **Purpose**: Guest VM traffic, Public IP, System VMs
- **Traffic Types**: Guest, Public
- **Features**:
  - VXLAN-based network isolation
  - Guest VM external communication

#### CloudStack Management Network (cloudbr1)
- **Purpose**: Internal management traffic, storage communication
- **Traffic Types**: Management, Storage
- **Features**:
  - Management Server ↔ Hypervisor communication
  - Hypervisor ↔ NFS Storage communication

**Important**: The two networks are completely independent and are NOT in a subnetting/supernetting relationship.

## Key Components

### Management Server 
- CloudStack Management Service
- CloudStack Usage Server
- MySQL Database (local or remote)
- Web UI: http://<management-server-ip>:8080/client

### Database Server 
- MySQL 8.0
- CloudStack optimized configuration
  - max_connections: 500
  - innodb_buffer_pool_size: 2G
  - bind-address: 0.0.0.0 (remote access enabled)

### KVM Hypervisor 
- KVM + QEMU
- LibvirtD (TCP 16509 listening)
- CloudStack Agent
- Network Bridges: cloudbr0, cloudbr1

### NFS Storage 
- Installed separately from `storage-node/nfs-server` directory in repo
- Primary Storage, Secondary Storage
- NFS v3 export

## Documentation

- **[cloudstack/README.md](cloudstack/README.md)**: Detailed Ansible automation documentation
- **[cloudstack/INSTALL.md](cloudstack/INSTALL.md)**: Step-by-step installation guide

## License

Apache License 2.0

## References

- [Apache CloudStack Documentation](https://docs.cloudstack.apache.org/)
- [CloudStack 4.19 Release Notes](https://docs.cloudstack.apache.org/en/4.19.0.0/)
- [Ansible Documentation](https://docs.ansible.com/)

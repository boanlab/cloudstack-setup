# CloudStack Installation Guide

This document provides an automated installation guide for CloudStack 4.19 using Ansible.

## Architecture

CloudStack is a distributed IaaS platform composed of multiple layers. The architecture deployed through this project is as follows.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CloudStack Infrastructure                   │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  Management Node │      │  Database Node   │      │   Storage Node   │
│                  │      │                  │      │                  │
│ • CloudStack     │◄────►│ • MySQL 8.0      │      │ • NFS Server     │
│   Management     │      │ • Cloud Database │      │ • Primary        │
│   Server         │      │ • User Database  │      │   Storage        │
│ • Web UI         │      │                  │      │ • Secondary      │
│ • API Server     │      │                  │      │   Storage        │
│ • Usage Server   │      │                  │      │                  │
└──────────────────┘      └──────────────────┘      └──────────────────┘
         │                                                    │
         │                                                    │
         └────────────────────┬───────────────────────────────┘
                              │
                    Management Network (10.15.0.0/24)
                              │
         ┌────────────────────┼───────────────────────────────┐
         │                    │                               │
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   KVM Host 1     │  │   KVM Host 2     │  │   KVM Host N     │
│                  │  │                  │  │                  │
│ • KVM/QEMU       │  │ • KVM/QEMU       │  │ • KVM/QEMU       │
│ • libvirt        │  │ • libvirt        │  │ • libvirt        │
│ • CloudStack     │  │ • CloudStack     │  │ • CloudStack     │
│   Agent          │  │   Agent          │  │   Agent          │
│ • cloudbr0       │  │ • cloudbr0       │  │ • cloudbr0       │
│ • cloudbr1       │  │ • cloudbr1       │  │ • cloudbr1       │
└──────────────────┘  └──────────────────┘  └──────────────────┘
         │                    │                               │
         └────────────────────┼───────────────────────────────┘
                              │
                     Public Network (10.10.0.0/24)
                              │
                         [ Internet ]
```

### Main Components

#### 1. Management Node
- **CloudStack Management Server**: Central control and orchestration of entire cloud infrastructure
- **Usage Server**: Resource usage tracking and billing

#### 2. Database Node
- **MySQL 8.0**: CloudStack Management Database

#### 3. Storage Node
- **NFS Server**: Provides Primary and Secondary Storage for VM disks and templates to Compute Nodes and Secondary Storage VMs

#### 4. Compute Nodes (KVM Hosts)
- **KVM/QEMU**: Virtual machine execution environment
- **CloudStack Agent**: Communication agent with Management Server
- **Network Bridges**: 
  - `cloudbr0`: Management/Storage traffic
  - `cloudbr1`: Public/Guest traffic

### CloudStack Zone Structure

![Zone Architecture Image](images/zone-architecture.png)


## Requirements

To build a CloudStack environment, the following hardware, software, and network requirements must be met.

### Supported Environment

| Item | Version/Spec |
|------|--------------|
| CloudStack | 4.19.3.0 |
| OS | Ubuntu 24.04 LTS (Noble) |
| Database | MySQL 8.0 |
| Java | OpenJDK 11 |
| Hypervisor | KVM/QEMU |
| Network Mode | Advanced Zone (VXLAN) |
| Automation | Ansible 2.9+ |


### Minimum Specifications by Node

#### Management Node
| Item | Minimum | Recommended |
|------|---------|-------------|
| CPU | 2 Core | 4 Core |
| RAM | 4 GB | 8 GB |
| Disk | 50 GB | 100 GB (SSD) |
| Network | **2 NIC** (Management + Public) | **2 NIC** (Management + Public) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

#### Database Node
| Item | Minimum | Recommended |
|------|---------|-------------|
| CPU | 2 Core | 4 Core |
| RAM | 4 GB | 8 GB |
| Disk | 50 GB | 200 GB (SSD) |
| Network | **2 NIC** (Management + Public) | **2 NIC** (Management + Public) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

#### Storage Node (NFS)
| Item | Minimum | Recommended |
|------|---------|-------------|
| CPU | 2 Core | 4 Core |
| RAM | 4 GB | 8 GB |
| Disk | 200 GB | 500 GB+ (SSD) |
| Network | 1 NIC (Public) | 1 NIC (Public) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

#### KVM Host (Compute Node)
| Item | Minimum | Recommended |
|------|---------|-------------|
| CPU | 4 Core (VT-x/AMD-V support) | 8+ Core (VT-x/AMD-V support) |
| RAM | 8 GB | 16 GB+ |
| Disk | 100 GB | 500 GB+ (SSD) |
| Network | **2 NIC** (Management + Public) | **2 NIC** (Management + Public) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

> **Important**: KVM Host must have **CPU virtualization support** (Intel VT-x or AMD-V) enabled.

### Network Requirements
CloudStack Advanced Zone requires **at least 2 physically separated networks**:

#### 1️⃣ Management Network
- **CIDR Example**: `10.15.0.0/24`
- **Purpose**: 
  - CloudStack internal management traffic
  - Management Server ↔ Hypervisor communication
  - Hypervisor ↔ Storage(NFS) communication
  - Pod internal IP allocation
- **Required Nodes**: All nodes (Management, Database, Storage, KVM Hosts)

#### 2️⃣ Public Network
- **CIDR Example**: `10.10.0.0/24`
- **Purpose**:
  - Guest VM internet connectivity
  - Public IP allocation (Floating IP)
  - System VM (SSVM, CPVM) external communication
  - Virtual Router external interface
- **Required Nodes**: KVM Hosts only (Management is optional)

#### IP Allocation Plan Example
- management server and database server can co-locate on the same node.
- Public IP will be used for CloudStack System VMs (such as` Secondary Storage VM`, `VNC proxy VM`, `Virtual Router`).  

| Node | Management IP (10.15.0.0/24) | Public IP (10.10.0.0/24) |
|------|------------------------------|--------------------------|
| Management | 10.15.0.1 | 10.10.0.10 |
| Database | 10.15.0.1 | 10.10.0.10 |
| Storage (NFS) | - | 10.10.0.201 |
| KVM Host 1 | 10.15.0.101 | 10.10.0.101 |
| KVM Host 2 | 10.15.0.102 | 10.10.0.102 |
| Gateway | 10.15.0.1 | 10.10.0.1 |
| Pod IP Range | 10.15.0.2 - 10.15.0.254 | - |
| Public IP Range | - | 10.10.100.1 - 10.10.100.254 |

### Software Requirements

#### Ansible Controller (Local Machine)
- Ansible 2.9 or higher
- Python 3.8 or higher
- SSH access available (root or sudo privileges)

#### Target Nodes
- Ubuntu 24.04 LTS (Noble Numbat)
- SSH server enabled
- root or sudo privileged user
- Internet connection (for package downloads)

## Installation Steps

### 1. Inventory Configuration

#### Create hosts File

```bash
cd cloudstack/
cp inventory/hosts.example inventory/hosts
vi inventory/hosts
```

**Items to Modify:**

```ini
[management]
cloudstack-mgmt ansible_host=10.10.0.10    # Management Server IP

[database]
cloudstack-db ansible_host=10.10.0.11      # Database Server IP

[kvm-hosts]
kvm-host-01 ansible_host=10.10.0.21        # KVM Host 1 IP

[cloudstack:vars]
ansible_user=root                           # SSH user (root or sudo user)
```

> **Important**: 
> - **When using root user**: Root account login must be allowed in SSH (`PermitRootLogin yes` in `/etc/ssh/sshd_config`)
> - **When using sudo user**: Set `ansible_user` to a user with sudo privileges and add `--ask-become-pass` option when running playbook

---

### 2. Prepare Ansible Controller

Run the setup script to install Ansible and configure the SSH environment:

```bash
cd cloudstack/
sudo ./setup-ansible-controller.sh
```

This script will:
- Install Ansible and required packages (python3-pip, python3-netaddr, sshpass)
- Configure SSH settings for passwordless connection

---

### 3. Configure Inventory Files

After the Ansible controller setup, configure the inventory and variables:

**Create and edit inventory file:**

```bash
cp inventory/hosts.example inventory/hosts
vi inventory/hosts
```

Update the IP addresses and ansible_user according to your environment.

**Configure passwords:**

```bash
vi inventory/group_vars/all/vault.yml
```

Set passwords for root, MySQL, and CloudStack.

**Configure network settings:**

```bash
vi inventory/group_vars/all/all.yml
```

Set network CIDRs, gateway, and storage paths.

> Please refer to the comments in each file and [OPTIONS.md](OPTIONS.md) for detailed configuration options.
---

### 4. Copy SSH Keys

Run the SSH key distribution script:

```bash
sudo ./copy-ssh-keys.sh
```

This script will:
- Check or generate SSH key if not exists
- Read hosts from inventory/hosts
- Copy SSH public key to all target servers

**Connection Test:**

```bash
# Ansible connection test
ansible all -i inventory/hosts -m ping
```

---

### 5. Network CIDR Configuration

Modify the network ranges in `inventory/group_vars/all/all.yml` to match your actual environment.

```bash
vi inventory/group_vars/all/all.yml
```
> Please Refer the [Network Requirements](###-Network-Requirements) section for CIDR examples.


> **Important**: Bridge names will be used as Traffic Labels during Zone configuration.

> Also, Check [OPTIONS.md](../cloudstack/OPTIONS.md) for detailed configuration options.
---

### 6. CloudStack Deployment

#### Full Automated Installation (Recommended)

```bash
# Automated installation of all components (steps 00~04), when using root user
ansible-playbook -i inventory/hosts playbooks/site.yml

# When using Vault encryption
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass
```

#### Step-by-Step Installation

You can run each step individually for debugging if issues occur.

```bash
# 0. Network bridge configuration
ansible-playbook -i inventory/hosts playbooks/00-setup-network.yml

# 1. Common preparation (NTP, packages, etc.)
ansible-playbook -i inventory/hosts playbooks/01-prepare-common.yml

# 2. Database installation
ansible-playbook -i inventory/hosts playbooks/02-setup-database.yml

# 3. Management Server installation
ansible-playbook -i inventory/hosts playbooks/03-setup-management.yml

# 4. KVM Hosts installation
ansible-playbook -i inventory/hosts playbooks/04-setup-kvm-hosts.yml
```

---

### 7. Installation Verification

#### Access Management Server

```bash
# Access Management Server UI
http://[Management-Server-IP]:8080/client
```

**Default Login Credentials:**
- Username: `admin`
- Password: `password`

#### Check Service Status

```bash
# On Management Server
systemctl status cloudstack-management

# On Database Server
systemctl status mysql

# On KVM Host
systemctl status libvirtd
```

## Next Steps

After completing the installation, proceed with Zone configuration to make CloudStack operational:

**[Zone Configuration Guide](../mgmt-node/zone-initialization-guide.md)**

The Zone configuration includes:
- Installing CloudMonkey CLI tool
- Generating API keys
- Creating and configuring CloudStack Zone
- Adding storage and compute resources
- Enabling the Zone

## Troubleshooting

For details, see [troubleshooting.md](troubleshooting.md).


## References

- Configuration Options: [../cloudstack/OPTIONS.md](../cloudstack/OPTIONS.md)
- Project Overview: [../README.md](../README.md)
- CloudStack Official Documentation: https://docs.cloudstack.apache.org/

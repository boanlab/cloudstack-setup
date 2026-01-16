# CloudStack Ansible Configuration Options

This document provides detailed explanations of all configuration files and modifiable options in the CloudStack Ansible automation project.

---

## Required Configuration Files

### 1. `inventory/hosts`

Defines server IP addresses and SSH connection information.

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `ansible_host` | Required | IP address of each node | `10.10.0.10` |
| `ansible_user` | Required | SSH connection username | `root` |
| `ansible_python_interpreter` | Optional | Python interpreter path | `/usr/bin/python3` |

**Example:**
```ini
[management]
cloudstack-mgmt ansible_host=10.10.0.10

[database]
cloudstack-db ansible_host=10.10.0.11

[kvm-hosts]
kvm-host-01 ansible_host=10.10.0.21
kvm-host-02 ansible_host=10.10.0.22

[cloudstack:vars]
ansible_user=root
ansible_python_interpreter=/usr/bin/python3
```

---

### 2. `group_vars/all/all.yml`

Common settings applied to all nodes.

#### User-Configurable Options

##### Network Configuration (Required)

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `public_network_cidr` | Required | Public network CIDR (externally accessible) | `10.10.0.0/24` |
| `management_network_cidr` | Required | Management network CIDR (internal communication only) | `10.15.0.0/24` |
| `management_bridge` | Optional | Management network bridge name | `cloudbr0` |
| `public_bridge` | Optional | Public network bridge name | `cloudbr1` |

> **Important**: Bridge names will be used as Traffic Labels during Zone configuration.

##### System Configuration (Optional)

| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `timezone` | Optional | System timezone | `Asia/Seoul` |

##### DNS and NTP Configuration (Optional)

| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `dns_servers` | Optional | DNS server list | `[168.126.63.1, 8.8.8.8]` |
| `ntp_servers` | Optional | NTP server list | `[0.pool.ntp.org, 1.pool.ntp.org]` |

##### Firewall and SELinux (Optional)

| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `configure_firewall` | Optional | Whether to configure firewall | `true` |
| `selinux_state` | Optional | SELinux state (CentOS/RHEL only) | `permissive` |

**Example:**
```yaml
# Network CIDR configuration (Required)
public_network_cidr: "10.10.0.0/24"
management_network_cidr: "10.15.0.0/24"

# Network bridge names (Optional)
management_bridge: "cloudbr0"
public_bridge: "cloudbr1"

# System configuration (Optional)
timezone: "Asia/Seoul"

# DNS servers (Optional)
dns_servers:
  - 168.126.63.1
  - 8.8.8.8

# NTP servers (Optional)
ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org

# Firewall configuration (Optional)
configure_firewall: true

# SELinux configuration (Optional)
selinux_state: permissive
```

---

### 3. `group_vars/all/vault.yml`

Stores passwords and sensitive information. Encryption with Ansible Vault is recommended.

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `vault_mysql_root_password` | Required | MySQL root account password | `SecureMySQL!123` |
| `vault_cloudstack_db_password` | Required | CloudStack database password | `CloudDB!456` |

**Example:**
```yaml
vault_mysql_root_password: "SecureMySQL!123"
vault_cloudstack_db_password: "CloudDB!456"
```

**Encryption Method:**
```bash
# Encrypt file
ansible-vault encrypt group_vars/all/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/all/vault.yml

# Decrypt file
ansible-vault decrypt group_vars/all/vault.yml
```

---

### 4. `group_vars/management/management.yml`

Management Server related configuration.

#### User-Configurable Options

##### NFS Server Configuration (Required)

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `nfs_server` | Required | NFS server IP address | `10.10.0.12` |
| `nfs_export_path` | Optional | NFS export base path | `/export` |
| `nfs_secondary_path` | Required | Secondary Storage NFS path | `/export/secondary` |
| `nfs_primary_path` | Required | Primary Storage NFS path | `/export/primary` |

##### Secondary Storage Mount Configuration (Optional)

| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `secondary_storage_mount_path` | Optional | Secondary Storage mount path | `/mnt/secondary` |
| `mount_secondary_storage` | Optional | Whether to mount Secondary Storage | `true` |
| `nfs_mount_options` | Optional | NFS mount options | `defaults` |

##### SystemVM Template Configuration (Optional)

| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `force_template_install` | Optional | Force template reinstallation | `false` |

#### Auto-Configured Options (Do Not Modify)

| Option | Description | Default |
|--------|-------------|---------|
| `management_server_ip` | Management Server IP (auto-configured) | `{{ ansible_host }}` |
| `cloudstack_management_memory` | Management Server memory (MB) | `4096` |
| `cloudstack_management_port` | Management Server port | `8080` |
| `db_host` | Database server IP (auto-configured) | `{{ hostvars[groups['database'][0]]['ansible_host'] }}` |
| `db_port` | Database port | `3306` |
| `cloudstack_db_password` | CloudStack DB password (vault linked) | `{{ vault_cloudstack_db_password }}` |
| `mysql_root_password` | MySQL root password (vault linked) | `{{ vault_mysql_root_password }}` |

**Example:**
```yaml
# NFS Server Configuration (Required)
nfs_server: "10.10.0.12"
nfs_export_path: "/export"
nfs_secondary_path: "/export/secondary"
nfs_primary_path: "/export/primary"

# Secondary Storage Mount Configuration (Optional)
secondary_storage_mount_path: "/mnt/secondary"
mount_secondary_storage: true
nfs_mount_options: "defaults"

# SystemVM Template Configuration (Optional)
force_template_install: false

#####################
# Do Not Modify Below
#####################

# Management Server Configuration
management_server_ip: "{{ ansible_host }}"

# CloudStack UI Configuration
cloudstack_management_memory: 4096
cloudstack_management_port: 8080

# Database Connection Information
db_host: "{{ hostvars[groups['database'][0]]['ansible_host'] }}"
db_port: 3306

# CloudStack Database Password
cloudstack_db_password: "{{ vault_cloudstack_db_password }}"
mysql_root_password: "{{ vault_mysql_root_password }}"
```

---

## Optional Configuration Files

### `group_vars/database/database.yml`

Database server related configuration. Generally does not need modification.

### `group_vars/kvm-hosts/kvm-hosts.yml`

KVM Hypervisor related configuration. Generally does not need modification.

### `ansible.cfg`

Ansible execution configuration file. Generally does not need modification.

---

## Configuration Priority

Ansible variables are applied in the following priority order (highest first):

1. Command line options (`-e` or `--extra-vars`)
2. `group_vars/all/vault.yml` (encrypted variables)
3. `group_vars/[group]/` (group-specific variables)
4. `group_vars/all/all.yml` (common variables)
5. Role defaults (`roles/*/defaults/main.yml`)

---

## Frequently Asked Questions

### Q1. Can Management and Database be installed on the same server?

Yes, it's possible. Use the same IP in `inventory/hosts`:
```ini
[management]
cloudstack-all ansible_host=10.10.0.10

[database]
cloudstack-all ansible_host=10.10.0.10
```

### Q2. Can I change the bridge names?

Yes, but you must use the same bridge names as Traffic Labels during Zone configuration.

---

## References

- Main Guide: [README.md](README.md)
- CloudStack Official Documentation: https://docs.cloudstack.apache.org/

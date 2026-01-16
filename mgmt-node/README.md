# CloudStack Zone Management Tools

This directory contains scripts and tools for CloudStack Zone configuration and management.

## Overview

After completing the infrastructure installation using Ansible, use these tools to configure and manage your CloudStack Zone.

## Files

### Configuration Scripts

- **[setup-cloudstack-zone.sh](setup-cloudstack-zone.sh)**: Automated Zone configuration script
  - Creates Zone, Pod, Cluster
  - Configures Physical Network and Traffic Types
  - Adds KVM Hosts
  - Registers Primary and Secondary Storage
  - Enables the Zone

- **[zone-config.yml.example](zone-config.yml.example)**: Zone configuration template
  - Copy to `zone-config.yml` and customize for your environment
  - Contains Zone, Network, Pod, Cluster, and Storage settings

### Utility Scripts

- **[install-cloudmonkey.sh](install-cloudmonkey.sh)**: CloudMonkey CLI installation
  - Downloads and installs CloudMonkey binary
  - Supports Linux x86-64

- **[register-primary-storage.sh](register-primary-storage.sh)**: Add Primary Storage to existing Zone
- **[register-secondary-storage.sh](register-secondary-storage.sh)**: Add Secondary Storage to existing Zone
- **[reinstall-systemvm.sh](reinstall-systemvm.sh)**: Reinstall System VMs (SSVM, CPVM) if System VMs have issues

> Please Refer **[SETUP-GUIDE.md](SETUP-GUIDE.md)** to get detailed instructions on using these tools.

## Quick Start

### 1. Install CloudMonkey

```bash
sudo ./install-cloudmonkey.sh
```

### 2. Generate API Keys

Login to CloudStack UI and generate API keys:
- URL: `http://[Management-Server-IP]:8080/client`
- Account: `admin` / Password: `password`
- Navigate to: Account → admin → Generate Keys

### 3. Configure CloudMonkey

```bash
cmk set url http://YOUR-MGMT-SERVER:8080/client/api
cmk set apikey YOUR-API-KEY
cmk set secretkey YOUR-SECRET-KEY
```

```
cmk sync
```

### 4. Create Zone Configuration

```bash
cp zone-config.yml.example zone-config.yml
vi zone-config.yml
```

Edit the following key settings:
- Management Server URL and credentials
- Network configuration (Management/Public CIDRs, gateway)
- Pod IP ranges
- KVM Host IPs
- Storage paths (NFS)

> beware that bridge names in `traffic_labels` must match those configured in Ansible.
### 5. Execute Zone Configuration

```bash
./setup-cloudstack-zone.sh zone-config.yml
```

This will automatically configure your CloudStack Zone.

### 6. Verify Installation

```bash
# List zones
cmk list zones

# Check hosts status
cmk list hosts type=Routing

# Check system VMs
cmk list systemvms
```

## References

- [CloudStack Official Documentation](https://docs.cloudstack.apache.org/)
- [CloudMonkey GitHub](https://github.com/apache/cloudstack-cloudmonkey)
- [CloudStack API Documentation](https://cloudstack.apache.org/api.html)

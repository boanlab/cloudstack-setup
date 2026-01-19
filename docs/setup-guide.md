# CloudStack Zone Configuration Guide

This guide explains how to configure a CloudStack Zone after infrastructure installation is complete.

## Prerequisites

- CloudStack infrastructure installation completed (Management Server, Database, KVM Hosts)
- Management Server accessible and running
- All services in healthy state

---

## 1. Install CloudMonkey

Install CloudMonkey on your Ansible Controller (or local machine):

```bash
cd mgmt-node/
sudo ./install-cloudmonkey.sh
```

> **Note**: CloudMonkey is a CLI tool that remotely calls CloudStack API.

---

## 2. Generate API Key

Generate API Key from CloudStack Web UI:

```bash
# 1. Access CloudStack UI in browser
http://[Management-Server-IP]:8080/client

# 2. Login
# Username: admin
# Password: password

# 3. Generate API Key
# - Click admin account in top right corner
# - Select "Generate Keys" or "API Key" menu
# - Copy API Key and Secret Key (to be used in zone-config.yml)
```

---

## 3. Create Zone Configuration File

Create `mgmt-node/zone-config.yml` file and modify it for your actual environment:

```bash
cd mgmt-node/
cp zone-config.yml.example zone-config.yml
vi zone-config.yml
```

> **Important Notes:**
> - Bridge names in `traffic_labels` must match `management_bridge` and `public_bridge` configured in Ansible
> - `hosts[].ip` must use IP addresses from the Management network (Pod network)
> - Public IP range must be from an actually usable Public network range
> - If you need some details about each options, refer to [OPTIONS.md](../cloudstack/OPTIONS.md)

---

## 4. Execute Zone Configuration

Run the Zone configuration script locally:

```bash
# Execute Zone configuration (from local Ansible Controller)
./setup-cloudstack-zone.sh zone-config.yml
```

> **Note**: CloudMonkey remotely calls the CloudStack Management Server API.

The script automatically performs the following tasks:

1. Create Zone
2. Configure Physical Network
3. Configure Traffic Types (Management, Guest, Public, Storage)
4. Add Public IP Range
5. Create Pod
6. Configure IP Range
7. Create Cluster
8. Add KVM Hosts
9. Add Primary Storage
10. Add Secondary Storage
11. Enable Zone

---

## 5. Verify Installation

After Zone configuration is complete, verify in CloudStack Web UI:

```bash
# 1. Access Web UI
http://[Management-Server-IP]:8080/client

# 2. Verify in Infrastructure menu
# - Zones: Verify Zone is in "Enabled" state
# - Pods: Verify Pod is created successfully
# - Clusters: Verify Cluster is created successfully
# - Hosts: Verify KVM Hosts are in "Up" state
# - Primary Storage: Verify Primary Storage is in "Up" state
# - Secondary Storage: Verify Secondary Storage is in "Up" state

# 3. Verify System VMs
# Infrastructure > System VMs
# - SSVM (Secondary Storage VM): Verify Running state
# - CPVM (Console Proxy VM): Verify Running state
```

**Wait for System VMs to Start:**

When you first enable a Zone, System VMs (SSVM, CPVM) are automatically created. This process may take 5-10 minutes.

```bash
# Check System VM status (using CloudMonkey)
cmk list systemvms

# Or check via logs
tail -f /var/log/cloudstack/management/management-server.log
```

---

## Next Steps

After Zone configuration is complete:

1. **Create Networks**: Set up isolated or shared networks for VMs
2. **Add Templates**: Upload VM templates (ISO or disk images)
3. **Launch Instances**: Create and manage virtual machines

---

## References

- [Installation Guide](../docs/installation.md)
- [Configuration Options](../cloudstack/OPTIONS.md)
- [CloudStack Official Documentation](https://docs.cloudstack.apache.org/)
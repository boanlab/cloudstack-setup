# CloudStack Troubleshooting Guide

This document explains common issues and solutions when using the CloudStack Ansible automation project.

## Connection Issues

### SSH Connection Failure

**Symptoms:**
- "Host unreachable" or "Permission denied" error when running Ansible playbook

**Solution:**

```bash
# 1. Test SSH connection directly
ssh [ansible_user]@[target-ip]

# 2. Verify SSH key is properly copied
ssh-copy-id [ansible_user]@[target-ip]

# 3. Test Ansible connection (with verbose logging)
ansible all -i inventory/hosts -m ping -vvv

# 4. Test specific host only
ansible management -i inventory/hosts -m ping -vvv
```

**Check:**
- Verify SSH service is running on target server: `systemctl status sshd`
- Check root login permission: `PermitRootLogin yes` in `/etc/ssh/sshd_config`
- Also, Check the root password is set correctly if using password authentication.
- Verify SSH port (22) is allowed in firewall: `ufw status` or `firewall-cmd --list-all`

---

## Database Issues

### MySQL Remote Connection Failure

**Symptoms:**
- Connection failure from Management Server to Database server
- "Can't connect to MySQL server" error

**Solution:**

```bash
# Run MySQL binding address fix playbook
ansible-playbook -i inventory/hosts playbooks/fix-mysql-binding.yml

# Or manually check on Database server
ssh [database-server]
sudo vi /etc/mysql/mysql.conf.d/mysqld.cnf
# Set bind-address = 0.0.0.0
sudo systemctl restart mysql
```

**Verification:**

```bash
# On Database server
# 1. Verify MySQL is listening on all interfaces
netstat -tulpn | grep 3306
# Result should be: 0.0.0.0:3306 (not 127.0.0.1:3306)

# 2. Check MySQL user privileges
mysql -u root -p
SELECT user, host FROM mysql.user WHERE user='cloud';
# host should be '%' or Management Server IP

# 3. Check firewall
sudo ufw status
sudo ufw allow 3306/tcp
```

---

## SystemVM Issues

### SSVM (Secondary Storage VM) Certificate Error

**Symptoms:**
- SSVM fails to start properly
- SystemVM status shows "Down" or "Error" in CloudStack UI
- SSL/TLS certificate related errors in logs

**Solution:**

```bash
# Run SSVM certificate fix playbook
ansible-playbook -i inventory/hosts playbooks/troubleshoot-ssvm.yml
```

**Manual Fix:**

```bash
# On Management Server
ssh [management-server]

# 1. Check SystemVM status
cmk list systemvms type=secondarystoragevm

# 2. Restart SSVM
cmk stop systemvm id=[ssvm-id]
cmk start systemvm id=[ssvm-id]

# 3. Check SSVM logs
tail -f /var/log/cloudstack/management/management-server.log | grep SSVM
```



## CloudStack Service Issues


### System VMs not starting

> Sometimes System VMs (SSVM, CPVM) may not start properly after Zone configuration. the VMs will be created but remain in "Starting" state.

Check System VM status:
```bash
cmk list systemvms
tail -f /var/log/cloudstack/management/management-server.log
```

System VMs may take 5-10 minutes to start after Zone enablement.

If System VM issues persist, reinstall them using:

```bash
# On Management Server
ssh [management-server]

./reinstall-systemvm.sh

# or


# 1. Remove existing template
/usr/share/cloudstack-common/scripts/storage/secondary/cloud-install-sys-tmplt \
  -m /mnt/secondary \
  -f /path/to/systemvmtemplate.qcow2.bz2 \
  -h kvm \
  -o localhost \
  -r cloud \
  -d cloud

# 2. Restart CloudStack Management
systemctl restart cloudstack-management
```

### Cannot find Shared Network Service Offering and Isolated Network Service Offering

If you cannot find the network service offerings when creating networks, ensure that the network provider `virtualrouter` is enabled.   

Enable Virtual Router network provider:

```bash
cmk update networkoffering id=$(cmk list networkofferings name="DefaultIsolatedNetworkOffering" filter=name,id --quiet) state=Enabled
cmk update networkoffering id=$(cmk list networkofferings name="DefaultSharedNetworkOffering" filter=name,id --quiet) state=Enabled
``` 
### VM Image is not started to download

All of the managing template image and ISO images are downloaded on Secondary StorageVM (SSVM). You should check the SSVM routing and network connectivity to the external network.

**Problem**: SSVM configure routing tables with Zone Configuration. However, DNS connection is routed on Management Network which may not have external network access.

**Solution 1: Remove wrong route configuration on SSVM (not recommended)**

Manually fix routing on SSVM, but this will be reset on SSVM reboot:

```bash
# SSH to SSVM
ssh USER@COMPUTE-NODE-IP

# Find SSVM (s-[0-9]-VM)
virsh list 

# Access SSVM console
# username: root
# password: password
virsh console <ssvm-name>

# Check current routes
ip route

# remove wrong route via Management Network such as...
# 8.8.8.8 via <management-network-gateway-ip>
# 8.8.4.4 via <management-network-gateway-ip>

# Remove incorrect route and add correct one
ip route del default
ip route add default via <correct-gateway-ip>
```

**Solution 2: Configure SNAT rule (recommended)**

Configure SNAT on the Pod Gateway node to allow Management Network access to external network through Public Network.

SSVM automatically uses the Pod Network gateway defined in your `zone-config.yml` (under `pod.gateway`). By configuring SNAT on that gateway node, SSVM can reach the internet:

```bash
# On the Pod Gateway node (matching pod.gateway IP in zone-config.yml)
# Assuming:
# - Pod/Management Network: 10.15.0.0/24
# - Pod Gateway: 10.15.0.1
# - Public Network interface: eth1

# 1. Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# 2. Add SNAT rule (replace <public-interface> with actual interface name)
iptables -t nat -A POSTROUTING -s 10.15.0.0/24 -o eth1 -j MASQUERADE

# 3. Make persistent
apt-get install iptables-persistent
netfilter-persistent save

# 4. Verify NAT rule
iptables -t nat -L POSTROUTING -n -v
```

**Verify SSVM connectivity:**

```bash
# List SSVM
cmk list systemvms systemvmtype=secondarystoragevm

# SSH to SSVM
ssh -i /var/cloudstack/management/.ssh/id_rsa -p 3922 root@<ssvm-linklocal-ip>

# On SSVM, verify gateway and connectivity
ip route show | grep default
ping -c 3 8.8.8.8
nslookup download.cloudstack.org
```

> **Note**: Replace network CIDRs and interface names with your actual configuration.


### VMs in Isolated Network cannot communicate with each other

If VMs in the same isolated network cannot communicate with each other, this is usually caused by MTU (Maximum Transmission Unit) mismatch.

**Problem**: When using VXLAN or other overlay networks, the effective MTU is reduced due to encapsulation overhead. If the Virtual Router's MTU is too large, packets will be fragmented or dropped.

Check with ping tests from a VM to another VM in the same isolated network:
```
ping -s 1500 <VM-IP>          # Standard MTU 1500
ping -s 1450 <VM-IP>          # Reduced MTU 1450
ping -s 1400 <VM-IP>          # Further reduced MTU 1400
```

> Detailed reason summaried on this page [Selective Packet Loss Over VXLAN (fat packet dropped)](https://constantpinger.home.blog/2022/09/27/selective-packet-loss-over-vxlan-fat-packets-dropped/)

**Solution**: Set the Virtual Router's MTU to `(smallest MTU in network path) - 50`

For example, if your physical network uses MTU 1500:
- VXLAN adds ~50 bytes overhead
- Safe Virtual Router MTU = 1500 - 50 = **1450**

**How to configure:**

Set zone-level MTU configurations using CloudMonkey:

```bash
# Set maximum MTU for Virtual Router public interfaces
cmk update configuration name=vr.public.interface.max.mtu value=1450

# Set maximum MTU for Virtual Router private interfaces
cmk update configuration name=vr.private.interface.max.mtu value=1450
```

After changing these settings, restart Virtual Routers to apply the new MTU:

```bash
# List Virtual Routers
cmk list routers listall=true

# Restart each router
cmk rebootrouter id=<router-id>
```

> **Note**: These zone-level configurations control the maximum allowed MTU values for public and private interfaces on Virtual Routers. Common MTU values:
> - Standard network: MTU 1500 → Virtual Router MTU **1450**
> - Jumbo frames (9000): MTU 9000 → Virtual Router MTU **8950**
> - Always test connectivity after MTU changes


## Log File Locations

### Management Server

```
/var/log/cloudstack/management/
├── management-server.log          # Main log
├── api-server.log                 # API request log
└── cloudstack-management.log      # System log
```

### KVM Host

```
/var/log/cloudstack/agent/
└── agent.log                      # Agent log

/var/log/libvirt/
└── libvirtd.log                   # libvirt log
```

### Database

```
/var/log/mysql/
└── error.log                      # MySQL error log
```

## References

- Installation Guide: [installation.md](installation.md)
- Project Overview: [../README.md](../README.md)

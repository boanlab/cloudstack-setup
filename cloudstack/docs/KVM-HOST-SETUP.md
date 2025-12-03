# KVM Host 설정 가이드

이 문서는 CloudStack KVM 호스트 설정에 대한 추가 정보를 제공합니다.

## 네트워크 인터페이스 확인

KVM 호스트 설정 전에 반드시 실제 네트워크 인터페이스 이름을 확인하세요:

```bash
# 방법 1
ip link

# 방법 2
ip addr

# 방법 3
ls /sys/class/net/
```

일반적인 인터페이스 이름:
- `eno1`, `eno2` - Dell, HP 등 서버
- `eth0`, `eth1` - 일반적인 이름
- `enp1s0`, `enp2s0` - 최신 Ubuntu
- `ens3`, `ens4` - 가상 머신

## 네트워크 브리지 구조

CloudStack은 두 개의 브리지를 사용합니다:

### cloudbr0 (Management Network)
- CloudStack Management 서버와 통신
- 일반적으로 Private IP 사용
- 예: 10.5.0.0/24

### cloudbr1 (Guest/Public Network)
- VM들의 네트워크
- Public IP 사용
- 예: 10.0.0.0/16

## 수동 네트워크 설정 (권장)

Ansible로 자동 설정 시 SSH 연결이 끊길 수 있으므로, 수동 설정을 권장합니다.

### 1. 현재 설정 백업

```bash
sudo cp /etc/netplan/*.yaml /etc/netplan/backup-$(date +%Y%m%d).yaml
```

### 2. Netplan 설정 파일 생성

```bash
sudo vi /etc/netplan/01-cloudstack-network.yaml
```

### 3. 설정 내용

**예시 1: 일반적인 구성**
```yaml
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: no
    eno2:
      dhcp4: no
  bridges:
    cloudbr0:
      interfaces: [eno2]
      addresses: [10.5.0.12/24]
      parameters:
        stp: false
        forward-delay: 0
    cloudbr1:
      interfaces: [eno1]
      addresses: [10.0.0.12/16]
      nameservers:
        addresses: [168.126.63.1, 8.8.8.8]
      routes:
        - to: default
          via: 10.0.0.1
      parameters:
        stp: false
        forward-delay: 0
```

**예시 2: 단일 인터페이스 (테스트용)**
```yaml
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: no
  bridges:
    cloudbr0:
      interfaces: [eno1]
      addresses: [192.168.1.100/24]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: default
          via: 192.168.1.1
      parameters:
        stp: false
        forward-delay: 0
```

### 4. 설정 검증 및 적용

```bash
# 설정 파일 문법 검증
sudo netplan generate

# 적용 (연결 끊길 수 있음!)
sudo netplan apply
```

### 5. 브리지 확인

```bash
# 브리지 목록
ip addr show cloudbr0
ip addr show cloudbr1

# 브리지 상세 정보
bridge link

# 라우팅 테이블
ip route
```

## Root SSH 로그인 설정

CloudStack Management가 KVM 호스트를 제어하려면 root SSH 접근이 필요합니다.

### 1. Root 비밀번호 설정

```bash
sudo passwd root
```

### 2. SSH 설정 변경

```bash
sudo vi /etc/ssh/sshd_config
```

다음 라인 추가/수정:
```
PermitRootLogin yes
```

### 3. SSH 재시작

```bash
sudo systemctl reload sshd
```

### 4. 테스트

```bash
ssh root@localhost
```

## Libvirt 설정 확인

### TCP 포트 리스닝 확인

```bash
# 포트 확인
sudo netstat -tulpn | grep 16509
# 또는
sudo ss -tulpn | grep 16509
```

출력 예시:
```
tcp   0   0 0.0.0.0:16509   0.0.0.0:*   LISTEN   1234/libvirtd
```

### Libvirtd 상태 확인

```bash
sudo systemctl status libvirtd
```

### Libvirt 설정 확인

```bash
# libvirtd.conf 확인
sudo grep -E "^(listen_tls|listen_tcp|tcp_port|auth_tcp)" /etc/libvirt/libvirtd.conf

# 출력 예상:
# listen_tls=0
# listen_tcp=1
# tcp_port = "16509"
# auth_tcp = "none"
```

## iptables 설정

### FORWARD 정책 확인

```bash
sudo iptables -L FORWARD -n
```

첫 줄이 `Chain FORWARD (policy ACCEPT)`이어야 합니다.

### FORWARD ACCEPT 설정

```bash
sudo iptables -P FORWARD ACCEPT

# 영구 저장
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
```

## 문제 해결

### 1. "Unable to connect to host" 오류

**원인**: Libvirtd가 TCP로 리스닝하지 않음

**해결**:
```bash
# Libvirtd 설정 확인
sudo systemctl status libvirtd

# 포트 확인
sudo netstat -tulpn | grep 16509

# Libvirtd 재시작
sudo systemctl restart libvirtd
```

### 2. "Network bridge not found" 오류

**원인**: 네트워크 브리지가 제대로 설정되지 않음

**해결**:
```bash
# 브리지 확인
ip addr show cloudbr0

# Netplan 재적용
sudo netplan apply

# 브리지 상태 확인
bridge link
```

### 3. VM이 네트워크에 연결되지 않음

**원인**: IP forwarding이 비활성화되어 있거나 iptables FORWARD 정책 문제

**해결**:
```bash
# IP forwarding 확인
sysctl net.ipv4.ip_forward

# IP forwarding 활성화
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# iptables FORWARD 정책 확인
sudo iptables -P FORWARD ACCEPT
```

### 4. Root SSH 접속 실패

**원인**: SSH 설정 또는 방화벽 문제

**해결**:
```bash
# SSH 설정 확인
sudo grep "^PermitRootLogin" /etc/ssh/sshd_config

# SSH 재시작
sudo systemctl reload sshd

# 방화벽 확인 (UFW)
sudo ufw status
sudo ufw allow 22/tcp
```

## Ansible 변수 설정 예시

### host_vars/kvm-host-01.yml

```yaml
---
# 네트워크 인터페이스 (ip link로 확인한 실제 이름)
public_interface: eno1
management_interface: eno2

# IP 설정
public_ip: 10.0.0.21
public_netmask: 16
management_ip: 10.5.0.21
management_netmask: 24
default_gateway: 10.0.0.1

# 네트워크 브리지 자동 설정 (권장하지 않음)
configure_network_bridge: false

# Root 비밀번호 해시 생성: mkpasswd --method=sha-512
root_password_hash: "$6$rounds=656000$YourHashHere"
```

## 검증 체크리스트

설치 후 다음 항목을 확인하세요:

- [ ] CloudStack Agent 설치됨 (`dpkg -l cloudstack-agent`)
- [ ] QEMU-KVM 설치됨 (`dpkg -l qemu-kvm`)
- [ ] Libvirtd 실행 중 (`systemctl status libvirtd`)
- [ ] Libvirtd TCP 포트 리스닝 (`netstat -tulpn | grep 16509`)
- [ ] 네트워크 브리지 설정됨 (`ip addr show cloudbr0 cloudbr1`)
- [ ] IP forwarding 활성화 (`sysctl net.ipv4.ip_forward`)
- [ ] iptables FORWARD ACCEPT (`iptables -L FORWARD -n`)
- [ ] Root SSH 로그인 가능 (`ssh root@kvm-host`)
- [ ] NFS 클라이언트 설치됨 (`dpkg -l nfs-common`)

Ansible 플레이북으로 자동 확인:
```bash
ansible-playbook -i inventory/hosts playbooks/verify-kvm-hosts.yml
```

## 참고 자료

- Compute-Node.md (원본 문서)
- CloudStack 공식 문서: https://docs.cloudstack.apache.org/
- KVM 공식 문서: https://www.linux-kvm.org/

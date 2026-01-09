# CloudStack 설치 가이드

이 문서는 Ansible을 사용한 CloudStack 4.19 자동 설치 가이드입니다.

## 사전 요구사항

- Ubuntu 24.04 LTS 서버
- root 또는 sudo 권한이 있는 사용자
- 최소 3대의 서버 (Management, Database, KVM Host)
- NFS 서버 (별도 또는 기존 서버와 통합 가능)

## 설치 단계

### 1. Inventory 설정

#### hosts 파일 생성

```bash
cd cloudstack/
cp inventory/hosts.example inventory/hosts
vi inventory/hosts
```

**수정해야 할 항목:**

```ini
[management]
cloudstack-mgmt ansible_host=10.10.0.10    # Management Server IP

[database]
cloudstack-db ansible_host=10.10.0.11      # Database Server IP

[kvm-hosts]
kvm-host-01 ansible_host=10.10.0.21        # KVM Host 1 IP
kvm-host-02 ansible_host=10.10.0.22        # KVM Host 2 IP (선택사항)

[cloudstack:vars]
ansible_user=root                           # SSH 접속 사용자 (root 또는 sudo 권한 사용자)
```

> **중요**: 
> - **root 사용자 사용 시**: SSH에서 root 계정 로그인이 허용되어 있어야 합니다 (`/etc/ssh/sshd_config`에서 `PermitRootLogin yes` 설정)
> - **sudo 사용자 사용 시**: `ansible_user`를 sudo 권한이 있는 사용자로 설정하고, playbook 실행 시 `--ask-become-pass` 옵션 추가

---

### 2. Ansible Controller 준비

```bash
# Ansible 및 필수 패키지 설치, SSH 키 생성 및 배포 안내
chmod +x setup-ansible-controller.sh
./setup-ansible-controller.sh
```

스크립트 실행 후 안내에 따라 각 노드에 SSH 키를 복사합니다:

```bash
# 각 노드에 SSH 키 복사 (예시)
ssh-copy-id root@10.10.0.10
ssh-copy-id root@10.10.0.11
ssh-copy-id root@10.10.0.21
ssh-copy-id root@10.10.0.22
```

**연결 테스트:**

```bash
# SSH 직접 연결 테스트
ssh root@10.10.0.10

# Ansible 연결 테스트
ansible all -i inventory/hosts -m ping
```

---

### 3. 네트워크 CIDR 설정

`inventory/group_vars/all/all.yml` 파일에서 네트워크 대역을 실제 환경에 맞게 수정합니다.

```bash
vi inventory/group_vars/all/all.yml
```

**필수 수정 항목:**

```yaml
# Public Network: 외부 접속 가능한 네트워크 대역
public_network_cidr: "10.10.0.0/24"         # 실제 Public 네트워크 CIDR로 변경

# Management Network: 내부 통신 전용 네트워크 대역
management_network_cidr: "10.15.0.0/24"     # 실제 Management 네트워크 CIDR로 변경

# 네트워크 브리지 이름 (기본값 사용 권장)
# 추후 Zone 설치하는 과정에서 해당 브릿지 정보를 traffic label에 사용해야 하므로 주의할 것
# 
# 각 네트워크 브릿지는 다음과 같이 설정됨
# management_network_cidr -> management_bridge
# pbulic_network_cidr -> public_bridge
management_bridge: "cloudbr0"               # Management Network 브리지 이름
public_bridge: "cloudbr1"                   # Public Network 브리지 이름
```

> **중요**: 브리지 이름은 Zone 설정 시 Traffic Label로 사용됩니다.

---

### 4. 비밀번호 설정

`inventory/group_vars/all/vault.yml` 파일에서 MySQL 및 CloudStack 비밀번호를 설정합니다.

```bash
vi inventory/group_vars/all/vault.yml
```

**필수 수정 항목:**

```yaml
vault_mysql_root_password: "your_secure_mysql_password"
vault_cloudstack_db_password: "your_secure_cloudstack_password"
```

**선택사항: Ansible Vault로 암호화**

```bash
# 비밀번호 파일 암호화
ansible-vault encrypt inventory/group_vars/all/vault.yml

# 암호화된 파일 편집 (암호화 후)
ansible-vault edit inventory/group_vars/all/vault.yml

# Playbook 실행 시 Vault 비밀번호 입력
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass
```

---

### 5. NFS Storage 설정

Management Server 설정 파일에서 NFS 서버 정보를 수정합니다.

```bash
vi inventory/group_vars/management/management.yml
```

**필수 수정 항목:**

```yaml
# NFS 서버 설정 (직접 입력) [필수]
nfs_server: "10.10.0.12"                    # NFS 서버 IP 주소
nfs_export_path: "/export"                  # NFS Export 기본 경로
nfs_secondary_path: "/export/secondary"     # Secondary Storage 경로
nfs_primary_path: "/export/primary"         # Primary Storage 경로
```

**선택사항:**

```yaml
# Secondary Storage 마운트 설정
secondary_storage_mount_path: "/mnt/secondary"
mount_secondary_storage: true
nfs_mount_options: "defaults"

# SystemVM Template 설정
force_template_install: false               # true로 설정 시 템플릿 강제 재설치
```

> **참고**: "이하 수정 금지" 섹션 이하의 설정은 자동으로 구성되므로 수정하지 마세요.

---

### 6. CloudStack 배포

#### 전체 자동 설치 (권장)

```bash
# 모든 컴포넌트 자동 설치 (00~04 단계), root 유저로 진행 시 
ansible-playbook -i inventory/hosts playbooks/site.yml

# sudo 사용자인 경우 --ask-become-pass 추가
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-become-pass

# Vault 암호화를 사용한 경우
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass
```

#### 단계별 설치

문제 발생 시 단계별로 실행하여 디버깅할 수 있습니다.

```bash
# 0. 네트워크 브리지 설정
ansible-playbook -i inventory/hosts playbooks/00-setup-network.yml

# 1. 공통 준비 (NTP, 패키지 등)
ansible-playbook -i inventory/hosts playbooks/01-prepare-common.yml

# 2. Database 설치
ansible-playbook -i inventory/hosts playbooks/02-setup-database.yml

# 3. Management Server 설치
ansible-playbook -i inventory/hosts playbooks/03-setup-management.yml

# 4. KVM Hosts 설치
ansible-playbook -i inventory/hosts playbooks/04-setup-kvm-hosts.yml
```

---

### 7. 설치 확인

#### Management Server 접속

```bash
# Management Server UI 접속
http://[Management-Server-IP]:8080/client
```

**기본 로그인 정보:**
- Username: `admin`
- Password: `password`

#### 서비스 상태 확인

```bash
# Management Server에서
systemctl status cloudstack-management

# Database Server에서
systemctl status mysql

# KVM Host에서
systemctl status libvirtd
```

---

## 8. Zone 설정

CloudStack 인프라 설치가 완료되면 Zone을 설정해야 합니다.

### 8.1. CloudMonkey 설치

로컬 Ansible Controller에 CloudMonkey를 설치합니다:

```bash
cd mgmt-node/
chmod +x install-cloudmonkey.sh
./install-cloudmonkey.sh
```

> **참고**: CloudMonkey는 로컬에 설치하여 CloudStack API를 원격으로 호출합니다.

### 8.2. API Key 생성

CloudStack Web UI에서 API Key를 생성합니다:

```bash
# 1. 브라우저에서 CloudStack UI 접속
http://[Management-Server-IP]:8080/client

# 2. 로그인
# Username: admin
# Password: password

# 3. API Key 생성
# - 우측 상단 admin 계정 클릭
# - "Generate Keys" 또는 "API Key" 메뉴 선택
# - API Key와 Secret Key 복사 (zone-config.yml에 사용)
```

### 8.3. Zone 설정 파일 생성

`mgmt-node/zone-config.yml` 파일을 생성하고 실제 환경에 맞게 수정합니다:

```bash
cd mgmt-node/
cp zone-config.yml.example zone-config.yml
vi zone-config.yml
```

**필수 수정 항목:**

```yaml
# CloudStack API Settings
cloudstack:
  url: "http://10.10.0.10:8080/client/api"  # Management Server URL
  api_key: "your-api-key-here"               # Web UI에서 생성한 API Key
  secret_key: "your-secret-key-here"         # Web UI에서 생성한 Secret Key

# Zone Configuration
zone:
  name: "Zone1"                               # Zone 이름
  dns1: "168.126.63.1"                       # Public DNS 1
  dns2: "8.8.8.8"                            # Public DNS 2
  internal_dns1: "168.126.63.1"              # Internal DNS 1
  internal_dns2: "8.8.8.8"                   # Internal DNS 2
  network_type: "Advanced"                    # Basic 또는 Advanced
  guest_cidr: "10.1.0.0/16"                  # Guest VM 네트워크 대역

# Physical Network Configuration
physical_network:
  name: "PhysicalNetwork"
  isolation_method: "VXLAN"                   # VLAN, VXLAN, GRE 등
  vlan_range: "100-200"                       # VLAN ID 범위 (VLAN 사용 시)
  
  # Traffic Type Labels (Ansible에서 설정한 브리지 이름과 일치해야 함)
  traffic_labels:
    management: "cloudbr0"                    # Management 트래픽 브리지
    guest: "cloudbr1"                         # Guest 트래픽 브리지
    public: "cloudbr1"                        # Public 트래픽 브리지
    storage: "cloudbr0"                       # Storage 트래픽 브리지

# Public IP Range Configuration
public_ip_range:
  start_ip: "10.10.0.50"                     # Public IP 시작
  end_ip: "10.10.0.100"                      # Public IP 끝
  gateway: "10.10.0.1"                       # Gateway
  netmask: "255.255.255.0"                   # Netmask
  vlan: "untagged"                           # "untagged" 또는 VLAN ID

# Pod Configuration
pod:
  name: "Pod1"
  gateway: "10.15.0.1"                       # Management 네트워크 Gateway
  netmask: "255.255.255.0"                   # Management 네트워크 Netmask
  start_ip: "10.15.0.50"                     # Management IP 풀 시작
  end_ip: "10.15.0.100"                      # Management IP 풀 끝

# Cluster Configuration
cluster:
  name: "Cluster1"
  hypervisor: "KVM"                          # KVM, VMware, XenServer 등
  type: "CloudManaged"                       # CloudManaged 또는 ExternalManaged

# Host Configuration (KVM Host 추가)
hosts:
  - name: "kvm-host-01"
    ip: "10.15.0.21"                         # KVM Host Management IP (Pod 네트워크)
    username: "root"
    password: "your-kvm-root-password"       # KVM Host root 비밀번호
  - name: "kvm-host-02"
    ip: "10.15.0.22"
    username: "root"
    password: "your-kvm-root-password"

# Primary Storage Configuration
primary_storage:
  name: "Primary-NFS"
  server: "10.10.0.12"                       # NFS 서버 IP
  path: "/export/primary"                    # NFS Export 경로
  scope: "cluster"                           # cluster 또는 zone

# Secondary Storage Configuration
secondary_storage:
  name: "Secondary-NFS"
  server: "10.10.0.12"                       # NFS 서버 IP
  path: "/export/secondary"                  # NFS Export 경로
  provider: "NFS"                            # NFS, S3, Swift 등
```

> **중요 사항:**
> - `traffic_labels`의 브리지 이름은 Ansible에서 설정한 `management_bridge`, `public_bridge`와 일치해야 합니다
> - `hosts[].ip`는 Management 네트워크(Pod 네트워크)의 IP 주소를 사용해야 합니다
> - Public IP 범위는 실제 사용 가능한 Public 네트워크 대역이어야 합니다

### 8.4. Zone 설정 실행

Zone 설정 스크립트를 로컬에서 실행합니다:

```bash
# Zone 설정 실행 (로컬 Ansible Controller에서)
./setup-cloudstack-zone.sh zone-config.yml
```

> **참고**: CloudMonkey가 원격으로 CloudStack Management Server API를 호출합니다.

스크립트는 다음 작업을 자동으로 수행합니다:

1. Zone 생성
2. Physical Network 설정
3. Traffic Type 설정 (Management, Guest, Public, Storage)
4. Public IP 범위 추가
5. Pod 생성
6. IP 범위 설정
7. Cluster 생성
8. KVM Host 추가
9. Primary Storage 추가
10. Secondary Storage 추가
11. Zone 활성화

### 8.5. 설치 확인

Zone 설정이 완료되면 CloudStack Web UI에서 확인합니다:

```bash
# 1. Web UI 접속
http://[Management-Server-IP]:8080/client

# 2. Infrastructure 메뉴에서 확인
# - Zones: Zone이 "Enabled" 상태인지 확인
# - Pods: Pod가 정상적으로 생성되었는지 확인
# - Clusters: Cluster가 정상적으로 생성되었는지 확인
# - Hosts: KVM Host가 "Up" 상태인지 확인
# - Primary Storage: Primary Storage가 "Up" 상태인지 확인
# - Secondary Storage: Secondary Storage가 "Up" 상태인지 확인

# 3. System VMs 확인
# Infrastructure > System VMs
# - SSVM (Secondary Storage VM): Running 상태 확인
# - CPVM (Console Proxy VM): Running 상태 확인
```

**System VM 시작 대기:**

Zone을 처음 활성화하면 System VM(SSVM, CPVM)이 자동으로 생성됩니다. 이 과정은 5-10분 정도 소요될 수 있습니다.

```bash
# System VM 상태 확인 (CloudMonkey 사용)
cmk list systemvms

# 또는 로그로 확인
tail -f /var/log/cloudstack/management/management-server.log
```

---

## 문제 해결

자세한 내용은 [troubleshooting.md](troubleshooting.md)를 참고하세요.
---

## 참고

- 설정 옵션 상세: [../cloudstack/OPTIONS.md](../cloudstack/OPTIONS.md)
- 프로젝트 개요: [../README.md](../README.md)
- CloudStack 공식 문서: https://docs.cloudstack.apache.org/

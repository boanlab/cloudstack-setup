# CloudStack Ansible 설치 가이드

문서 기반으로 작성된 CloudStack 4.19.2.0 자동 설치 Ansible 프로젝트입니다.

## 사전 요구사항

- Ansible 2.9 이상
- Ubuntu 22.04 대상 서버
- SSH 접근 가능한 서버들
- 최소 3대의 서버 (Management, Database, Storage - 통합 가능)

## 빠른 시작

### 1. 인벤토리 파일 생성

```bash
cp inventory/hosts.example inventory/hosts
vi inventory/hosts
```

실제 서버 IP로 수정하세요.

### 2. Vault 파일 생성 (암호 설정)

```bash
cp group_vars/vault.yml.example group_vars/vault.yml
vi group_vars/vault.yml
```

MySQL 및 CloudStack 데이터베이스 비밀번호를 설정하세요.

암호화 (선택사항):
```bash
ansible-vault encrypt group_vars/vault.yml
```

### 3. 호스트별 변수 설정 (KVM 호스트)

KVM 호스트의 네트워크 인터페이스와 IP를 설정:

```bash
cp host_vars/kvm-host-01.yml.example host_vars/kvm-host-01.yml
vi host_vars/kvm-host-01.yml
```

**중요**: 네트워크 인터페이스 이름을 확인하세요:
```bash
ssh kvm-host-01 "ip link"
```

### 4. 전체 설치 실행

```bash
# Vault를 암호화하지 않은 경우
ansible-playbook -i inventory/hosts playbooks/site.yml

# Vault를 암호화한 경우
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass
```

### 5. 개별 컴포넌트 설치

특정 컴포넌트만 설치하려면:

```bash

# 데이터베이스만
ansible-playbook -i inventory/hosts playbooks/03-setup-database.yml

# Management 서버만
ansible-playbook -i inventory/hosts playbooks/04-setup-management.yml

# KVM 호스트만
ansible-playbook -i inventory/hosts playbooks/05-setup-kvm-hosts.yml
```

## 설치 순서

Ansible은 다음 순서로 설치를 진행합니다:

1. **공통 설정** (`common` role)
   - 기본 패키지 설치
   - NTP 설정
   - 시스템 설정

2. **데이터베이스** (`database` role)
   - MySQL 설치 및 설정
   - CloudStack용 최적화

3. **Management 서버** (`management` role)
   - CloudStack Management 패키지 설치
   - SystemVM 템플릿 설치
   - 데이터베이스 초기화
   - Management 서버 시작

4. **KVM 호스트** (`kvm-host` role)
   - KVM 및 libvirt 설치
   - CloudStack Agent 설치
   - Libvirtd TCP 리스닝 설정
   - 네트워크 브리지 설정 (선택)
   - Root SSH 로그인 활성화
   - iptables FORWARD 정책 설정

## KVM 호스트 설정

### 네트워크 브리지 설정

KVM 호스트는 **네트워크 브리지 설정이 필수**입니다. 두 가지 방법이 있습니다:

#### 방법 1: Ansible로 자동 설정 (권장하지 않음 - 연결 끊김)

```bash
# host_vars/kvm-host-01.yml에서 설정
configure_network_bridge: true
```

⚠️ **경고**: 네트워크 설정 변경 시 SSH 연결이 끊길 수 있습니다.

#### 방법 2: 수동 설정 (권장)

각 KVM 호스트에 직접 접속하여 설정:

```bash
sudo vi /etc/netplan/01-cloudstack-network.yaml
```

```yaml
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: no
    eno2:
      dhcp4: no
  bridges:
    cloudbr0:  # Management Network
      interfaces: [eno2]
      addresses: [10.5.0.12/24]
      parameters:
        stp: false
        forward-delay: 0
    cloudbr1:  # Guest/Public Network
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

적용:
```bash
sudo netplan generate
sudo netplan apply
```

### KVM 호스트 준비 상태 확인

```bash
ansible-playbook -i inventory/hosts playbooks/verify-kvm-hosts.yml
```

이 플레이북은 다음을 확인합니다:
- CloudStack Agent 설치
- QEMU-KVM 설치
- Libvirtd 실행 상태
- Libvirtd TCP 포트 (16509) 리스닝
- 네트워크 브리지 (cloudbr0, cloudbr1)
- iptables FORWARD 정책
- IP forwarding 활성화
- Root SSH 접근
- NFS 클라이언트 설치

### Root 비밀번호 설정

CloudStack Management에서 KVM 호스트를 추가할 때 root 비밀번호가 필요합니다.

비밀번호 해시 생성:
```bash
mkpasswd --method=sha-512
```

`host_vars/kvm-host-01.yml`에 추가:
```yaml
root_password_hash: "$6$rounds=656000$..."
```

## 접속 정보

설치 완료 후:

- **Web UI**: http://[management-server-ip]:8080/client
- **기본 계정**: admin / password
- **로그 확인**: 
  ```bash
  tail -f /var/log/cloudstack/management/management-server.log
  ```

## CloudStack에 KVM 호스트 추가

1. CloudStack UI 로그인
2. Infrastructure → Hosts → Add Host
3. 다음 정보 입력:
   - **Zone**: 생성한 Zone 선택
   - **Pod**: 생성한 Pod 선택
   - **Cluster**: 생성한 Cluster 선택
   - **Hostname**: KVM 호스트 IP (예: 10.5.0.12)
   - **Username**: root
   - **Password**: root 계정 비밀번호

## 문제 해결

### "There is no Secondary Storage VM" 오류

Management 서버에서 다음 설정을 변경:

1. CloudStack UI → Global Settings
2. `ca.framework.cert.systemvm.allow.host.ip` → `true`
3. `ca.plugin.root.auth.strictness` → `false`
4. `systemctl restart cloudstack-management`

또는 플레이북 실행:
```bash
ansible-playbook -i inventory/hosts playbooks/troubleshoot-ssvm.yml
```

### SystemVM 템플릿 문제

템플릿 재설치:

```bash
ansible-playbook -i inventory/hosts playbooks/reinstall-systemvm.yml
```

### KVM 호스트 연결 실패

1. **Libvirtd TCP 확인**:
   ```bash
   ssh root@kvm-host "netstat -tulpn | grep 16509"
   ```

2. **네트워크 브리지 확인**:
   ```bash
   ssh root@kvm-host "ip addr show cloudbr0 && ip addr show cloudbr1"
   ```

3. **Root SSH 확인**:
   ```bash
   ssh root@kvm-host "whoami"
   ```

4. **iptables FORWARD 정책**:
   ```bash
   ssh root@kvm-host "iptables -L FORWARD -n | head -1"
   ```
   ACCEPT 정책이어야 합니다.

### 네트워크 브리지 문제

브리지가 제대로 작동하지 않으면:

```bash
# 인터페이스 확인
ip link

# 브리지 상태 확인
bridge link

# 브리지 삭제 후 재생성
sudo ip link set cloudbr0 down
sudo brctl delbr cloudbr0
sudo netplan apply
```

## 주요 변수

### group_vars/all.yml
- `cloudstack_version`: CloudStack 버전
- `systemvm_template_url`: SystemVM 템플릿 URL
- `ntp_servers`: NTP 서버 목록

### group_vars/vault.yml
- `vault_mysql_root_password`: MySQL root 비밀번호
- `vault_cloudstack_db_password`: CloudStack DB 비밀번호

### group_vars/nfs-storage.yml
- `storage_device`: 스토리지 디스크 (예: /dev/sdb)
- `nfs_export_path`: NFS export 경로

### group_vars/kvm-hosts.yml
- `public_interface`: Public 네트워크 인터페이스 (기본: eno1)
- `management_interface`: Management 네트워크 인터페이스 (기본: eno2)
- `enable_root_ssh`: Root SSH 로그인 활성화
- `configure_iptables_forward`: iptables FORWARD 정책 설정

### host_vars/kvm-host-XX.yml
- `public_ip`: Public IP 주소
- `management_ip`: Management IP 주소
- `default_gateway`: 기본 게이트웨이
- `configure_network_bridge`: 네트워크 브리지 자동 설정 여부
- `root_password_hash`: Root 계정 비밀번호 해시

## 유용한 명령어

```bash
# KVM 호스트 상태 확인
ansible-playbook -i inventory/hosts playbooks/verify-kvm-hosts.yml

# 특정 호스트만 설치
ansible-playbook -i inventory/hosts playbooks/05-setup-kvm-hosts.yml --limit kvm-host-01

# 네트워크 설정만 변경 (주의!)
ansible-playbook -i inventory/hosts playbooks/configure-kvm-network.yml

# 문제 해결
ansible-playbook -i inventory/hosts playbooks/troubleshoot-ssvm.yml
```

## 참고 문서

원본 설치 문서:
- Management-Node.md
- Storage-node.md
- Compute-Node.md

## 라이선스

Apache 2.0

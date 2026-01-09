# CloudStack Ansible 설정 옵션

이 문서는 CloudStack Ansible 자동화 프로젝트의 모든 설정 파일과 수정 가능한 옵션을 상세히 설명합니다.

---

## 필수 수정 파일

### 1. `inventory/hosts`

서버의 IP 주소와 SSH 접속 정보를 정의하는 파일입니다.

| 옵션 | 필수 여부 | 설명 | 예시 |
|------|-----------|------|------|
| `ansible_host` | 필수 | 각 노드의 IP 주소 | `10.10.0.10` |
| `ansible_user` | 필수 | SSH 접속 사용자명 | `root` |
| `ansible_python_interpreter` | 선택 | Python 인터프리터 경로 | `/usr/bin/python3` |

**예시:**
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

모든 노드에 공통으로 적용되는 설정입니다.

#### 사용자 수정 가능 옵션

##### 네트워크 설정 (필수)

| 옵션 | 필수 여부 | 설명 | 예시 |
|------|-----------|------|------|
| `public_network_cidr` | 필수 | Public 네트워크 CIDR (외부 접속 가능) | `10.10.0.0/24` |
| `management_network_cidr` | 필수 | Management 네트워크 CIDR (내부 통신 전용) | `10.15.0.0/24` |
| `management_bridge` | 선택 | Management 네트워크 브리지 이름 | `cloudbr0` |
| `public_bridge` | 선택 | Public 네트워크 브리지 이름 | `cloudbr1` |

> **중요**: 브리지 이름은 Zone 설정 시 Traffic Label로 사용됩니다.

##### 시스템 설정 (선택)

| 옵션 | 필수 여부 | 설명 | 기본값 |
|------|-----------|------|--------|
| `timezone` | 선택 | 시스템 타임존 | `Asia/Seoul` |

##### DNS 및 NTP 설정 (선택)

| 옵션 | 필수 여부 | 설명 | 기본값 |
|------|-----------|------|--------|
| `dns_servers` | 선택 | DNS 서버 리스트 | `[168.126.63.1, 8.8.8.8]` |
| `ntp_servers` | 선택 | NTP 서버 리스트 | `[0.pool.ntp.org, 1.pool.ntp.org]` |

##### 방화벽 및 SELinux (선택)

| 옵션 | 필수 여부 | 설명 | 기본값 |
|------|-----------|------|--------|
| `configure_firewall` | 선택 | 방화벽 설정 여부 | `true` |
| `selinux_state` | 선택 | SELinux 상태 (CentOS/RHEL만 해당) | `permissive` |

**예시:**
```yaml
# 네트워크 CIDR 설정 (필수)
public_network_cidr: "10.10.0.0/24"
management_network_cidr: "10.15.0.0/24"

# 네트워크 브리지 이름 (선택)
management_bridge: "cloudbr0"
public_bridge: "cloudbr1"

# 시스템 설정 (선택)
timezone: "Asia/Seoul"

# DNS 서버 (선택)
dns_servers:
  - 168.126.63.1
  - 8.8.8.8

# NTP 서버 (선택)
ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org

# 방화벽 설정 (선택)
configure_firewall: true

# SELinux 설정 (선택)
selinux_state: permissive
```

---

### 3. `group_vars/all/vault.yml`

비밀번호 및 민감 정보를 저장하는 파일입니다. Ansible Vault로 암호화를 권장합니다.

| 옵션 | 필수 여부 | 설명 | 예시 |
|------|-----------|------|------|
| `vault_mysql_root_password` | 필수 | MySQL root 계정 비밀번호 | `SecureMySQL!123` |
| `vault_cloudstack_db_password` | 필수 | CloudStack 데이터베이스 비밀번호 | `CloudDB!456` |

**예시:**
```yaml
vault_mysql_root_password: "SecureMySQL!123"
vault_cloudstack_db_password: "CloudDB!456"
```

**암호화 방법:**
```bash
# 파일 암호화
ansible-vault encrypt group_vars/all/vault.yml

# 암호화된 파일 편집
ansible-vault edit group_vars/all/vault.yml

# 암호화 해제
ansible-vault decrypt group_vars/all/vault.yml
```

---

### 4. `group_vars/management/management.yml`

Management Server 관련 설정입니다.

#### 사용자 수정 가능 옵션

##### NFS 서버 설정 (필수)

| 옵션 | 필수 여부 | 설명 | 예시 |
|------|-----------|------|------|
| `nfs_server` | 필수 | NFS 서버 IP 주소 | `10.10.0.12` |
| `nfs_export_path` | 선택 | NFS Export 기본 경로 | `/export` |
| `nfs_secondary_path` | 필수 | Secondary Storage NFS 경로 | `/export/secondary` |
| `nfs_primary_path` | 필수 | Primary Storage NFS 경로 | `/export/primary` |

##### Secondary Storage 마운트 설정 (선택)

| 옵션 | 필수 여부 | 설명 | 기본값 |
|------|-----------|------|--------|
| `secondary_storage_mount_path` | 선택 | Secondary Storage 마운트 경로 | `/mnt/secondary` |
| `mount_secondary_storage` | 선택 | Secondary Storage 마운트 여부 | `true` |
| `nfs_mount_options` | 선택 | NFS 마운트 옵션 | `defaults` |

##### SystemVM Template 설정 (선택)

| 옵션 | 필수 여부 | 설명 | 기본값 |
|------|-----------|------|--------|
| `force_template_install` | 선택 | Template 강제 재설치 여부 | `false` |

#### 자동 설정 옵션 (수정 금지)

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `management_server_ip` | Management Server IP (자동 설정) | `{{ ansible_host }}` |
| `cloudstack_management_memory` | Management Server 메모리 (MB) | `4096` |
| `cloudstack_management_port` | Management Server 포트 | `8080` |
| `db_host` | Database 서버 IP (자동 설정) | `{{ hostvars[groups['database'][0]]['ansible_host'] }}` |
| `db_port` | Database 포트 | `3306` |
| `cloudstack_db_password` | CloudStack DB 비밀번호 (vault 연동) | `{{ vault_cloudstack_db_password }}` |
| `mysql_root_password` | MySQL root 비밀번호 (vault 연동) | `{{ vault_mysql_root_password }}` |

**예시:**
```yaml
# NFS 서버 설정 (필수)
nfs_server: "10.10.0.12"
nfs_export_path: "/export"
nfs_secondary_path: "/export/secondary"
nfs_primary_path: "/export/primary"

# Secondary Storage 마운트 설정 (선택)
secondary_storage_mount_path: "/mnt/secondary"
mount_secondary_storage: true
nfs_mount_options: "defaults"

# SystemVM Template 설정 (선택)
force_template_install: false

###############
# 이하 수정 금지 #
###############

# Management Server 설정
management_server_ip: "{{ ansible_host }}"

# CloudStack UI 설정
cloudstack_management_memory: 4096
cloudstack_management_port: 8080

# 데이터베이스 연결 정보
db_host: "{{ hostvars[groups['database'][0]]['ansible_host'] }}"
db_port: 3306

# CloudStack 데이터베이스 비밀번호
cloudstack_db_password: "{{ vault_cloudstack_db_password }}"
mysql_root_password: "{{ vault_mysql_root_password }}"
```

---

## 선택적 설정 파일

### `group_vars/database/database.yml`

Database 서버 관련 설정입니다. 일반적으로 수정할 필요가 없습니다.

### `group_vars/kvm-hosts/kvm-hosts.yml`

KVM Hypervisor 관련 설정입니다. 일반적으로 수정할 필요가 없습니다.

### `ansible.cfg`

Ansible 실행 설정 파일입니다. 일반적으로 수정할 필요가 없습니다.

---

## 설정 우선순위

Ansible 변수는 다음 우선순위로 적용됩니다 (높은 순서부터):

1. 명령줄 옵션 (`-e` 또는 `--extra-vars`)
2. `group_vars/all/vault.yml` (암호화된 변수)
3. `group_vars/[group]/` (그룹별 변수)
4. `group_vars/all/all.yml` (공통 변수)
5. Role defaults (`roles/*/defaults/main.yml`)

---

## 자주 묻는 질문

### Q1. Management와 Database를 같은 서버에 설치할 수 있나요?

네, 가능합니다. `inventory/hosts`에서 같은 IP를 사용하면 됩니다:
```ini
[management]
cloudstack-all ansible_host=10.10.0.10

[database]
cloudstack-all ansible_host=10.10.0.10
```

### Q2. 브리지 이름을 변경해도 되나요?

네, 하지만 Zone 설정 시 Traffic Label에도 동일한 브리지 이름을 사용해야 합니다.

---

## 참고

- 메인 가이드: [README.md](README.md)
- CloudStack 공식 문서: https://docs.cloudstack.apache.org/

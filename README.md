# CloudStack Infrastructure Automation

Apache CloudStack 4.19 완전 자동 배포를 위한 종합 인프라 구축 프로젝트입니다.

Ansible 기반 자동화로 Management Server, Database, KVM Hypervisor, NFS Storage, Advanced Zone까지 전체 CloudStack 인프라를 코드로 관리합니다.

**테스트 환경**: Ubuntu 24.04, CloudStack 4.19.2.0


## 디렉토리 구조

```
cloudstack-infra/
├── cloudstack/                    # Ansible 자동화 메인 디렉토리
│   ├── inventory/                 # 인벤토리 및 변수
│   │   ├── hosts                  # 호스트 정의 (management, database, kvm-hosts)
│   │   └── group_vars/            # 그룹별 변수
│   │
│   ├── playbooks/                 # Ansible 플레이북
│   │
│   ├── roles/                     # Ansible Roles
│   │   ├── common/                # 공통 설정 (NTP, apt lock 처리)
│   │   ├── database/              # MySQL 8.0 설치 및 최적화
│   │   ├── management/            # CloudStack Management + Usage Server
│   │   └── kvm-host/              # KVM + LibvirtD + Agent 설정
│   │
│   ├── README.md                  # CloudStack Ansible 문서
│   ├── INSTALL.md                 # 상세 설치 가이드
│   └── ansible.cfg                # Ansible 설정
│
├── storage-node/                  # NFS Storage 독립 설치
│   └── nfs-server/
│       └── setup-nfs-storage.sh   # NFS 서버 자동 설치 스크립트
│
├── mgmt-node/                     # Management 노드 유틸리티
│   ├── install-cloudmonkey.sh     # CloudMonkey CLI 설치
│   └── nfs-server/                # NFS 등록 스크립트
│       ├── register-primary-storage.sh
│       └── register-secondary-storage.sh
│
└── README.md                      # 이 파일
```

## 빠른 시작

### 사전 요구사항

- **Ansible 2.9+** (Control Node)
- **Ubuntu 24.04** (대상 서버)
- **최소 3대 서버**: Management, KVM Host, NFS Storage (통합 가능)
- **2개 네트워크**: Public , Management 
- **SSH 접근 권한** 및 **sudo 권한**: NOPASSWD 설정이 되어 있어야 함

### 1단계: 저장소 클론

```bash
git clone https://github.com/boanlab/cloudstack-infra.git
cd cloudstack-infra/cloudstack
```

### 2단계: 인벤토리 설정

```bash
# 인벤토리 파일 수정
vi inventory/hosts
```

실제 서버 IP 주소를 입력:
```ini
[management]
mgmt-server ansible_host=10.15.0.113

[database]
db-server ansible_host=10.15.0.113

[kvm-hosts]
kvm-host-01 ansible_host=10.15.0.114
```

### 3단계: 변수 설정

#### 3-1. Vault (비밀번호)

```bash
vi inventory/group_vars/vault.yml
```

```yaml
vault_mysql_root_password: "your_secure_password"
vault_cloudstack_db_password: "your_secure_password"
vault_kvm_host_password: "your_ssh_password"
```

#### 3-2. Zone 설정

```bash
vi inventory/group_vars/zone.yml
```

주요 설정:
- `zone_name`: Zone 이름
- `cloudstack_physical_networks`: Physical Network 및 Traffic Types
- `cloudstack_public_ip_ranges`: Public IP 범위 (System VM용)
- `cloudstack_pods`: Pod IP 범위
- `cloudstack_clusters`: Cluster 정의
- `cloudstack_hosts`: KVM Host 목록
- `cloudstack_primary_storages`: Primary Storage (NFS)
- `cloudstack_secondary_storages`: Secondary Storage (NFS)

### 4단계: NFS Storage 설치 (별도 서버)

NFS Storage는 Ansible과 별도로 독립 스크립트로 설치:

```bash
# NFS 서버에서 실행
cd storage-node/nfs-server
sudo ./setup-nfs-storage.sh -d /dev/sdb -y
```

### 5단계: CloudStack 인프라 배포

```bash
cd cloudstack
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-pass
```

**실행 순서:**
1. 네트워크 브리지 설정 (cloudbr0, cloudbr1)
2. 공통 패키지 설치 (NTP, 기본 유틸리티)
3. MySQL 설치 및 구성
4. Management Server 설치 및 초기화
5. KVM Hypervisor 설정

### 6단계: Zone 자동 구성

Management Server 설치 후 Web UI에서 API Key 생성:

1. http://<management-node-ip>:8080/client 접속
2. admin / password 로그인
3. Accounts → admin → View Users → admin → Keys
4. Generate Keys 클릭
5. `inventory/group_vars/zone.yml`에 API Key 입력

Zone 자동 구성 실행:

```bash
ansible-playbook -i inventory/hosts playbooks/05-setup-zone.yml --ask-pass
```

**자동 생성 내용:**
- Advanced Zone 생성
- Physical Network + Traffic Types (Management, Storage, Public, Guest)
- VXLAN VNI 범위 설정 (5000-6000)
- Public IP Range 추가
- Pod, Cluster, Host 추가
- Primary/Secondary Storage 등록

### 7단계: 접속 확인

```bash
# Web UI 접속
http://10.15.0.113:8080/client

# 기본 계정
Username: admin
Password: password
```

## 네트워크 아키텍처

### 2개의 독립 네트워크

#### CloudStack Public Network (cloudbr0)
- **용도**: Guest VM 트래픽, Public IP, System VM
- **Traffic Types**: Guest, Public
- **특징**:
  - VXLAN 기반 네트워크 격리
  - Guest VM 외부 통신

#### CloudStack Management Network (cloudbr1)
- **용도**: 내부 관리 트래픽, 스토리지 통신
- **Traffic Types**: Management, Storage
- **특징**:
  - Management Server ↔ Hypervisor 통신
  - Hypervisor ↔ NFS Storage 통신

**중요**: 두 네트워크는 완전히 독립적이며 Subnetting/Supernetting 관계가 아닙니다.

## 주요 컴포넌트

### Management Server 
- CloudStack Management Service
- CloudStack Usage Server
- MySQL Database (로컬 또는 원격)
- Web UI: http://<management-server-ip>:8080/client

### Database Server 
- MySQL 8.0
- CloudStack 최적화 설정
  - max_connections: 500
  - innodb_buffer_pool_size: 2G
  - bind-address: 0.0.0.0 (원격 접근 허용)

### KVM Hypervisor 
- KVM + QEMU
- LibvirtD (TCP 16509 listening)
- CloudStack Agent
- Network Bridges: cloudbr0, cloudbr1

### NFS Storage 
- 레포 내 `storage-node/nfs-server` 디렉토리에서 별도 설치
- Primary Storage, Secondary Storage
- NFS v3 export

## 문서

- **[cloudstack/README.md](cloudstack/README.md)**: Ansible 자동화 상세 문서
- **[cloudstack/INSTALL.md](cloudstack/INSTALL.md)**: 단계별 설치 가이드

## 라이선스

Apache License 2.0

## 참고

- [Apache CloudStack Documentation](https://docs.cloudstack.apache.org/)
- [CloudStack 4.19 Release Notes](https://docs.cloudstack.apache.org/en/4.19.0.0/)
- [Ansible Documentation](https://docs.ansible.com/)

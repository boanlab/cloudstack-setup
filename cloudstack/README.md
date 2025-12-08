# CloudStack Ansible Infrastructure

Apache CloudStack 설치를 자동화하는 Ansible 플레이북 프로젝트입니다.

**테스트 환경**: Ubuntu 24.04, CloudStack 4.19.2.0

## 배포 아키텍처

### 네트워크 구성

이 프로젝트는 **2개의 독립적인 물리 네트워크**를 사용하는 CloudStack Advanced Zone을 구성한다.

#### 1. CloudStack Public Network (cloudbr0)
- **용도**: Guest VM 트래픽, Public IP, System VM (SSVM, CPVM)
- **CIDR**: 10.10.0.0/16 (예시)
- **Traffic Types**: Guest, Public
- **특징**: 
  - Guest VM의 외부 통신
  - Public IP Range 할당
  - Floating IP 제공
  - VXLAN 기반 네트워크 격리 (VNI: 5000-6000)

#### 2. CloudStack Management Network (cloudbr1)
- **용도**: CloudStack 내부 관리 트래픽, 스토리지 트래픽, 관리 대시보드 (mgmt-ip:8080) 접근
- **CIDR**: 10.25.0.0/24 (예시)
- **Traffic Types**: Management, Storage
- **특징**:
  - Zone 내 Internal DNS 통신 대역
  - Management Server ↔ Hypervisor 통신
  - Pod IP Range (Management 트래픽용)


## 디렉토리 구조

```
cloudstack-infra/
├── inventory/              # 인벤토리 파일 (호스트 정의)
├── group_vars/            # 그룹별 변수
│   ├── all.yml           # 전체 공통 설정
│   ├── database.yml      # 데이터베이스 설정
│   ├── management.yml    # Management 서버 설정
│   ├── kvm-hosts.yml     # KVM 호스트 설정
│   ├── vault.yml         # 암호화된 비밀번호 (생성 필요)
│   └── zone.yml  
├── playbooks/             # 메인 플레이북 파일들
│   ├── site.yml                    # 전체 설치
│   ├── 01-prepare-common.yml       # 공통 설정
│   ├── 02-setup-database.yml       # 데이터베이스
│   ├── 03-setup-management.yml     # Management 서버
│   ├── 04-setup-kvm-hosts.yml      # KVM 호스트
│   ├── 05-setup-zone.yml      # KVM 호스트
│   ├── troubleshoot-ssvm.yml       # SSVM 문제 해결
│   └── reinstall-systemvm.yml      # SystemVM 템플릿 재설치
├── roles/                 # Ansible roles
│   ├── common/           # 공통 설정 (패키지, NTP 등)
│   ├── database/         # MySQL/MariaDB 설치 및 설정
│   ├── management/       # CloudStack Management Server
│   ├── kvm-host/         # KVM 하이퍼바이저 호스트
│   └── nfs-storage/      # NFS 스토리지 서버
├── ansible.cfg           # Ansible 설정 파일
├── README.md             # 이 파일
└── INSTALL.md            # 상세 설치 가이드
```

## 빠른 시작

### 1. 설정 파일 준비

```bash
# 인벤토리 파일 생성
cp inventory/hosts.example inventory/hosts
vi inventory/hosts

# Vault 파일 생성 (비밀번호 설정)
cp group_vars/vault.yml.example group_vars/vault.yml
vi group_vars/vault.yml

# KVM 호스트 설정 (필요시)
cp host_vars/kvm-host-01.yml.example host_vars/kvm-host-01.yml
vi host_vars/kvm-host-01.yml
```

### 2. 전체 설치 실행

```bash
ansible-playbook -i inventory/hosts playbooks/site.yml
```

## 상세 문서

**[INSTALL.md](INSTALL.md)** 파일을 참고하세요. 다음 내용을 포함합니다:

- 상세 설치 가이드
- 설정 방법
- 문제 해결 가이드
- 주요 변수 설명

## 요구사항

- Ansible 2.9+
- Python 3.6+
- 대상 서버: Ubuntu 22.04
- SSH 접근 권한
- sudo 권한

## 설치되는 컴포넌트

1. **NFS Storage**: Primary/Secondary 스토리지
2. **Database**: MySQL 8.0 (CloudStack용 최적화)
3. **Management Server**: CloudStack Management + Usage Server
4. **KVM Hosts**: KVM 하이퍼바이저 + CloudStack Agent

## 접속 정보

설치 완료 후 Management 서버 IP의 8080 포트로 접속:

- URL: http://[management-ip]:8080/client
- 기본 계정: admin / password

## 라이선스

Apache License 2.0

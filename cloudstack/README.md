# CloudStack Ansible Automation
<!-->
- 어떤 스크립트
    - 설명 
    - 사용 명령어
-->
CloudStack 4.19 인프라를 자동으로 배포하는 Ansible 프로젝트입니다.

## 빠른 시작

```bash
# 1. Inventory 설정
cp inventory/hosts.example inventory/hosts
vi inventory/hosts

# 2. 네트워크 및 비밀번호 설정
vi inventory/group_vars/all/all.yml
vi inventory/group_vars/all/vault.yml
vi inventory/group_vars/management/management.yml

# 3. Ansible Controller 준비
./setup-ansible-controller.sh

# 4. 배포 실행
ansible-playbook -i inventory/hosts playbooks/site.yml
```

> **상세 설치 가이드**: [../docs/installation.md](../docs/installation.md)

## Playbook 목록

| Playbook | 설명 |
|----------|------|
| `site.yml` | 전체 자동 설치 (00~04 단계 통합) |
| `00-setup-network.yml` | 네트워크 브리지 설정 |
| `01-prepare-common.yml` | 공통 준비 (NTP, 패키지 등) |
| `02-setup-database.yml` | MySQL Database 설치 |
| `03-setup-management.yml` | Management Server 설치 |
| `04-setup-kvm-hosts.yml` | KVM Hypervisor 설치 |

## Inventory 구조

```
inventory/
├── hosts                          # 서버 IP 주소 정의
├── hosts.example                  # 예시 파일
└── group_vars/
    ├── all/
    │   ├── all.yml               # 공통 설정 (네트워크 CIDR, 버전 등)
    │   └── vault.yml             # 비밀번호 (암호화 권장)
    ├── management/
    │   └── management.yml        # Management Server 설정 (NFS 정보)
    ├── database/
    │   └── database.yml          # Database 설정
    └── kvm-hosts/
        └── kvm-hosts.yml         # KVM Host 설정
```

## Ansible 명령어

### 연결 테스트

```bash
# 모든 노드 Ping 테스트
ansible all -i inventory/hosts -m ping

# 특정 그룹만 테스트
ansible management -i inventory/hosts -m ping
ansible kvm-hosts -i inventory/hosts -m ping
```

### 임시 명령 실행

```bash
# 서비스 상태 확인
ansible management -i inventory/hosts -m shell -a "systemctl status cloudstack-management"

# 디스크 사용량 확인
ansible all -i inventory/hosts -m shell -a "df -h"
```

## 설정 옵션

모든 설정 가능한 옵션과 상세한 설명은 [OPTIONS.md](OPTIONS.md)를 참고하세요.

## 참고

- 상세 설치 가이드: [../docs/installation.md](../docs/installation.md)
- 문제 해결: [../docs/troubleshooting.md](../docs/troubleshooting.md)
- CloudStack 공식 문서: https://docs.cloudstack.apache.org/

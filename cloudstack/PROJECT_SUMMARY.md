# CloudStack Ansible 프로젝트 구조

### 설정 파일
- `ansible.cfg` - Ansible 기본 설정
- `.gitignore` - Git 제외 파일
- `README.md` - 프로젝트 개요
- `INSTALL.md` - 상세 설치 가이드

### 인벤토리
- `inventory/hosts.example` - 인벤토리 예시

### 변수 파일
- `group_vars/all.yml` - 전체 공통 변수
- `group_vars/database.yml` - DB 서버 변수
- `group_vars/management.yml` - Management 서버 변수
- `group_vars/kvm-hosts.yml` - KVM 호스트 변수
- `group_vars/nfs-storage.yml` - NFS 스토리지 변수
- `group_vars/vault.yml.example` - 암호화 변수 예시

### 플레이북
- `playbooks/site.yml` - 전체 설치 메인 플레이북
- `playbooks/01-prepare-common.yml` - 공통 준비
- `playbooks/02-setup-database.yml` - 데이터베이스 설치
- `playbooks/03-setup-management.yml` - Management 서버 설치
- `playbooks/04-setup-kvm-hosts.yml` - KVM 호스트 설치
- `playbooks/05-setup-zone.yml` - KVM 호스트 설치
- `playbooks/troubleshoot-ssvm.yml` - SSVM 문제 해결
- `playbooks/reinstall-systemvm.yml` - SystemVM 템플릿 재설치

### Roles

#### Common (공통 설정)
- `roles/common/tasks/main.yml` - 기본 패키지, NTP 설정
- `roles/common/meta/main.yml` - Role 메타데이터

#### NFS Storage
- `roles/nfs-storage/tasks/main.yml` - NFS 서버 설정
- `roles/nfs-storage/handlers/main.yml` - NFS 재시작 핸들러
- `roles/nfs-storage/defaults/main.yml` - 기본 변수
- `roles/nfs-storage/meta/main.yml` - Role 메타데이터

#### Database
- `roles/database/tasks/main.yml` - MySQL 설치 및 설정
- `roles/database/handlers/main.yml` - MySQL 재시작 핸들러
- `roles/database/templates/root-my.cnf.j2` - MySQL 설정 템플릿
- `roles/database/defaults/main.yml` - 기본 변수
- `roles/database/meta/main.yml` - Role 메타데이터

#### Management
- `roles/management/tasks/main.yml` - Management 서버 설치
- `roles/management/defaults/main.yml` - 기본 변수
- `roles/management/meta/main.yml` - Role 메타데이터

#### KVM Host
- `roles/kvm-host/tasks/main.yml` - KVM 호스트 설정
- `roles/kvm-host/handlers/main.yml` - Libvirt 재시작 핸들러
- `roles/kvm-host/templates/netplan-bridge.yaml.j2` - 네트워크 브리지 템플릿
- `roles/kvm-host/defaults/main.yml` - 기본 변수
- `roles/kvm-host/meta/main.yml` - Role 메타데이터

## 주요 기능

### 자동화된 작업들

1. **NFS Storage 설정**
   - 디스크 파티셔닝 및 포맷
   - NFS 서버 설치 및 설정
   - Primary/Secondary 스토리지 디렉토리 생성
   - NFS export 설정

2. **Database 설정**
   - MySQL 8.0 설치
   - CloudStack용 최적화된 설정 적용
   - Root 비밀번호 설정
   - 보안 설정 (익명 사용자 제거 등)

3. **Management Server 설정**
   - Java 설치 (OpenJDK 11)
   - CloudStack 4.19.2.0 패키지 설치
   - SystemVM 템플릿 자동 다운로드 및 설치
   - 데이터베이스 초기화
   - Management 서버 시작

4. **KVM Host 설정**
   - KVM 및 libvirt 설치
   - CloudStack Agent 설치
   - Libvirt TCP 리스닝 설정
   - 네트워크 브리지 설정 (선택)
   - AppArmor 비활성화

5. **문제 해결 플레이북**
   - Secondary Storage VM 인증서 문제 자동 해결
   - SystemVM 템플릿 재설치

## 다음 단계

1. `inventory/hosts` 파일 작성
2. `group_vars/vault.yml` 생성 및 비밀번호 설정
3. 필요시 호스트별 변수 설정
4. 플레이북 실행

```bash
ansible-playbook -i inventory/hosts playbooks/site.yml
```

상세한 내용은 `INSTALL.md`를 참고하세요.

# CloudStack 문제 해결 가이드

이 문서는 CloudStack Ansible 자동화 프로젝트 사용 시 발생할 수 있는 문제와 해결 방법을 설명합니다.

## 연결 문제

### SSH 연결 실패

**증상:**
- Ansible playbook 실행 시 "Host unreachable" 또는 "Permission denied" 오류

**해결 방법:**

```bash
# 1. SSH 직접 연결 테스트
ssh [ansible_user]@[target-ip]

# 2. SSH 키가 제대로 복사되었는지 확인
ssh-copy-id [ansible_user]@[target-ip]

# 3. Ansible 연결 테스트 (상세 로그)
ansible all -i inventory/hosts -m ping -vvv

# 4. 특정 호스트만 테스트
ansible management -i inventory/hosts -m ping -vvv
```

**확인 사항:**
- target 서버에서 SSH 서비스가 실행 중인지 확인: `systemctl status sshd`
- root 로그인 허용 여부 확인: `/etc/ssh/sshd_config`에서 `PermitRootLogin yes`
- 방화벽에서 SSH 포트(22) 허용 확인: `ufw status` 또는 `firewall-cmd --list-all`

---

## Database 문제

### MySQL 원격 접속 실패

**증상:**
- Management Server에서 Database 서버로 연결 실패
- "Can't connect to MySQL server" 오류

**해결 방법:**

```bash
# MySQL 바인딩 주소 수정 playbook 실행
ansible-playbook -i inventory/hosts playbooks/fix-mysql-binding.yml

# 또는 수동으로 Database 서버에서 확인
ssh [database-server]
sudo vi /etc/mysql/mysql.conf.d/mysqld.cnf
# bind-address = 0.0.0.0 으로 설정
sudo systemctl restart mysql
```

**확인 사항:**

```bash
# Database 서버에서
# 1. MySQL이 모든 인터페이스에서 리스닝하는지 확인
netstat -tulpn | grep 3306
# 결과: 0.0.0.0:3306이어야 함 (127.0.0.1:3306이면 원격 접속 불가)

# 2. MySQL 사용자 권한 확인
mysql -u root -p
SELECT user, host FROM mysql.user WHERE user='cloud';
# host가 '%' 또는 Management Server IP여야 함

# 3. 방화벽 확인
sudo ufw status
sudo ufw allow 3306/tcp
```

---

## SystemVM 문제

### SSVM (Secondary Storage VM) 인증서 오류

**증상:**
- SSVM이 정상적으로 시작되지 않음
- CloudStack UI에서 SystemVM 상태가 "Down" 또는 "Error"
- 로그에 SSL/TLS 인증서 관련 오류

**해결 방법:**

```bash
# SSVM 인증서 문제 해결 playbook
ansible-playbook -i inventory/hosts playbooks/troubleshoot-ssvm.yml
```

**수동 해결:**

```bash
# Management Server에서
ssh [management-server]

# 1. SystemVM 상태 확인
cloudmonkey list systemvms type=secondarystoragevm

# 2. SSVM 재시작
cloudmonkey stop systemvm id=[ssvm-id]
cloudmonkey start systemvm id=[ssvm-id]

# 3. SSVM 로그 확인
tail -f /var/log/cloudstack/management/management-server.log | grep SSVM
```

### SystemVM Template 재설치

**증상:**
- SystemVM이 생성되지 않음 (Starting -> Error 무한 반복)
- Template이 손상되었거나 버전이 맞지 않음

**해결 방법:**

```bash
# 방법 1: force_template_install 옵션 사용
vi inventory/group_vars/management/management.yml
# force_template_install: true 로 설정

ansible-playbook -i inventory/hosts playbooks/03-setup-management.yml

# 방법 2: 재설치 playbook 사용
ansible-playbook -i inventory/hosts playbooks/reinstall-systemvm.yml
```

**수동 재설치:**

```bash
# Management Server에서
ssh [management-server]

# 1. 기존 Template 삭제
/usr/share/cloudstack-common/scripts/storage/secondary/cloud-install-sys-tmplt \
  -m /mnt/secondary \
  -f /path/to/systemvmtemplate.qcow2.bz2 \
  -h kvm \
  -o localhost \
  -r cloud \
  -d cloud

# 2. CloudStack Management 재시작
systemctl restart cloudstack-management
```

---

## 네트워크 문제

### 네트워크 브리지 설정 실패

**증상:**
- KVM Host에서 브리지가 생성되지 않음
- VM이 네트워크에 연결되지 않음

**해결 방법:**

```bash
# 네트워크 브리지 재설정
ansible-playbook -i inventory/hosts playbooks/00-setup-network.yml

# 브리지 상태 확인
ansible kvm-hosts -i inventory/hosts -m shell -a "ip addr show"
ansible kvm-hosts -i inventory/hosts -m shell -a "brctl show"
```

**수동 확인:**

```bash
# KVM Host에서
ssh [kvm-host]

# 1. 브리지 상태 확인
ip addr show cloudbr0
ip addr show cloudbr1

# 2. Netplan 설정 확인 (Ubuntu 24.04)
cat /etc/netplan/01-netcfg.yaml

# 3. 네트워크 재적용
netplan apply

# 4. libvirt 네트워크 확인
virsh net-list --all
```

---

## Ansible 문제

### Playbook 실행 중 오류

**증상:**
- Task 실행 중 특정 단계에서 실패

**해결 방법:**

```bash
# 1. 상세 로그로 실행
ansible-playbook -i inventory/hosts playbooks/site.yml -vvv

# 2. 특정 task부터 실행 (실패한 task 다음부터)
ansible-playbook -i inventory/hosts playbooks/site.yml --start-at-task="Task Name"

# 3. 특정 호스트만 실행
ansible-playbook -i inventory/hosts playbooks/site.yml --limit management

# 4. Dry-run 모드로 테스트
ansible-playbook -i inventory/hosts playbooks/site.yml --check
```

### Vault 비밀번호 관련 오류

**증상:**
- "Vault password required" 오류

**해결 방법:**

```bash
# Vault 비밀번호와 함께 실행
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass

# Vault 비밀번호 파일 사용
echo "your_vault_password" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-playbook -i inventory/hosts playbooks/site.yml --vault-password-file ~/.vault_pass
```

---

## CloudStack 서비스 문제

### Management Server 시작 실패

**증상:**
- `systemctl status cloudstack-management` 상태가 "failed"

**해결 방법:**

```bash
# Management Server에서
ssh [management-server]

# 1. 로그 확인
tail -f /var/log/cloudstack/management/management-server.log

# 2. Database 연결 확인
mysql -h [database-server] -u cloud -p[password] cloud

# 3. 포트 사용 확인
netstat -tulpn | grep 8080

# 4. 서비스 재시작
systemctl restart cloudstack-management
```

### KVM Host Agent 연결 실패

**증상:**
- CloudStack UI에서 Host 상태가 "Disconnected"

**해결 방법:**

```bash
# KVM Host에서
ssh [kvm-host]

# 1. Agent 상태 확인
systemctl status cloudstack-agent

# 2. Agent 로그 확인
tail -f /var/log/cloudstack/agent/agent.log

# 3. libvirt 상태 확인
systemctl status libvirtd

# 4. Management Server 연결 확인
telnet [management-server] 8250

# 5. Agent 재시작
systemctl restart cloudstack-agent
```

---

## NFS Storage 문제

### Secondary Storage 마운트 실패

**증상:**
- Management Server에서 Secondary Storage 마운트 불가
- "mount.nfs: access denied" 오류

**해결 방법:**

```bash
# NFS 서버에서
ssh [nfs-server]

# 1. NFS Export 확인
cat /etc/exports
# /export/secondary *(rw,async,no_root_squash,no_subtree_check)

# 2. Export 재적용
exportfs -ra

# 3. NFS 서비스 상태 확인
systemctl status nfs-server

# 4. 방화벽 확인
sudo ufw allow from [management-network] to any port nfs
```

**Management Server에서 테스트:**

```bash
ssh [management-server]

# 수동 마운트 테스트
mount -t nfs [nfs-server]:/export/secondary /mnt/test
df -h | grep /mnt/test
umount /mnt/test
```

---

## 로그 파일 위치

### Management Server

```
/var/log/cloudstack/management/
├── management-server.log          # 메인 로그
├── api-server.log                 # API 요청 로그
└── cloudstack-management.log      # 시스템 로그
```

### KVM Host

```
/var/log/cloudstack/agent/
└── agent.log                      # Agent 로그

/var/log/libvirt/
└── libvirtd.log                   # libvirt 로그
```

### Database

```
/var/log/mysql/
└── error.log                      # MySQL 에러 로그
```

## 참고

- 설치 가이드: [installation.md](installation.md)
- 프로젝트 개요: [../README.md](../README.md)

# CloudStack Infrastructure

> Apache CloudStack 4.19 자동 배포를 위한 Ansible 기반 Infrastructure as Code 프로젝트

**작성일**: 2025-12-31  
**버전**: CloudStack 4.19.3.0  
**테스트 환경**: Ubuntu 24.04 LTS

---

## 📋 목차

1. [Introduction](#introduction)
2. [Architecture](#architecture)
3. [Requirements](#requirements)
4. [Resources](#resources)

---

## Introduction

이 프로젝트는 **Apache CloudStack 4.19** 기반의 IaaS(Infrastructure as a Service) 클라우드 환경을 자동으로 구축하기 위한 Ansible 자동화 솔루션입니다.

### 프로젝트 목적

수동으로 CloudStack을 설치하는 과정은 복잡하고 오류가 발생하기 쉽습니다. 이 프로젝트는 다음을 목표로 합니다:

- ✅ **완전 자동화 배포**: Management Server, Database, KVM Hypervisor, NFS Storage의 설치 및 구성 자동화
- ✅ **재현 가능한 환경**: IaC(Infrastructure as Code) 방식으로 언제든 동일한 환경 재구성 가능
- ✅ **빠른 시작**: 복잡한 설정 과정을 최소화하여 빠르게 CloudStack 환경 구축
- ✅ **학습 및 테스트 환경**: CloudStack을 학습하거나 PoC(Proof of Concept) 환경 구축에 최적화

### 주요 기능

- 🚀 **완전 자동화 설치**: Ansible Playbook을 통한 원클릭 배포
- 🔧 **네트워크 자동 감지**: CIDR 기반으로 네트워크 인터페이스를 자동으로 찾아 브리지 구성
- 🌐 **Advanced Zone 지원**: VXLAN 기반 네트워크 격리 및 Floating IP 지원
- 🔐 **보안 강화**: Ansible Vault를 통한 비밀번호 및 민감 정보 암호화
- 📊 **고가용성 준비**: Database 분리 구성, 다중 KVM 호스트 지원
- 🛠️ **자동 문제 해결**: SSVM 인증서 문제, SystemVM 템플릿 재설치 자동화

### 지원 환경

| 항목 | 버전/사양 |
|------|-----------|
| CloudStack | 4.19.3.0 |
| OS | Ubuntu 24.04 LTS (Noble) |
| Database | MySQL 8.0 |
| Java | OpenJDK 11 |
| Hypervisor | KVM/QEMU |
| Network Mode | Advanced Zone (VXLAN) |
| Automation | Ansible 2.9+ |

---

## Architecture

CloudStack은 여러 계층으로 구성된 분산 IaaS 플랫폼입니다. 이 프로젝트를 통해 구축되는 아키텍처는 다음과 같습니다.

### 전체 시스템 구성도

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CloudStack Infrastructure                    │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  Management Node │      │  Database Node   │      │   Storage Node   │
│                  │      │                  │      │                  │
│ • CloudStack     │◄────►│ • MySQL 8.0      │      │ • NFS Server     │
│   Management     │      │ • Cloud Database │      │ • Primary        │
│   Server         │      │ • User Database  │      │   Storage        │
│ • Web UI         │      │                  │      │ • Secondary      │
│ • API Server     │      │                  │      │   Storage        │
│ • Usage Server   │      │                  │      │                  │
└──────────────────┘      └──────────────────┘      └──────────────────┘
         │                                                    │
         │                                                    │
         └────────────────────┬───────────────────────────────┘
                              │
                    Management Network (10.15.0.0/24)
                              │
         ┌────────────────────┼───────────────────────────────┐
         │                    │                               │
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   KVM Host 1     │  │   KVM Host 2     │  │   KVM Host N     │
│                  │  │                  │  │                  │
│ • KVM/QEMU       │  │ • KVM/QEMU       │  │ • KVM/QEMU       │
│ • libvirt        │  │ • libvirt        │  │ • libvirt        │
│ • CloudStack     │  │ • CloudStack     │  │ • CloudStack     │
│   Agent          │  │   Agent          │  │   Agent          │
│ • cloudbr0       │  │ • cloudbr0       │  │ • cloudbr0       │
│ • cloudbr1       │  │ • cloudbr1       │  │ • cloudbr1       │
└──────────────────┘  └──────────────────┘  └──────────────────┘
         │                    │                               │
         └────────────────────┼───────────────────────────────┘
                              │
                     Public Network (10.10.0.0/24)
                              │
                         [ Internet ]
```

### 주요 컴포넌트

#### 1. Management Node
- **CloudStack Management Server**: 전체 클라우드 인프라의 중앙 제어 및 오케스트레이션
- **Web UI**: 사용자 인터페이스 (기본 포트: 8080)
- **API Server**: RESTful API를 통한 프로그래밍 방식 제어
- **Usage Server**: 리소스 사용량 추적 및 빌링

#### 2. Database Node
- **MySQL 8.0**: CloudStack 메타데이터 저장
- **cloud**: CloudStack 핵심 데이터베이스
- **cloud_usage**: 사용량 데이터베이스

#### 3. Storage Node
- **NFS Server**: 중앙 집중식 스토리지 제공
- **Primary Storage**: VM 디스크 및 볼륨 저장
- **Secondary Storage**: ISO, 템플릿, 스냅샷 저장

#### 4. Compute Nodes (KVM Hosts)
- **KVM/QEMU**: 가상 머신 실행 환경
- **CloudStack Agent**: Management Server와의 통신 에이전트
- **Network Bridges**: 
  - `cloudbr0`: Management/Storage 트래픽
  - `cloudbr1`: Public/Guest 트래픽

### CloudStack Zone 구조

![Zone Architecture](/asset/zone-architecture.png)

```
Zone (데이터센터)
 └─ Physical Network 1 (Management/Storage)
 │   ├─ Traffic Type: Management
 │   └─ Traffic Type: Storage
 │
 └─ Physical Network 2 (Guest/Public)
     ├─ Traffic Type: Guest (VXLAN)
     └─ Traffic Type: Public
     
     └─ Pod (가용 영역)
         ├─ Cluster (KVM)
         │   ├─ KVM Host 1
         │   ├─ KVM Host 2
         │   └─ KVM Host N
         │
         ├─ Primary Storage (NFS)
         └─ Secondary Storage (NFS)
```

---

## Requirements

CloudStack 환경을 구축하기 위해서는 다음의 하드웨어, 소프트웨어, 네트워크 요구사항을 충족해야 합니다.

### 노드별 최소 스펙

#### Management Node
| 항목 | 최소 사양 | 권장 사양 |
|------|-----------|-----------|
| CPU | 2 Core | 4 Core |
| RAM | 4 GB | 8 GB |
| Disk | 50 GB | 100 GB (SSD) |
| Network | 1 NIC (Management) | 1 NIC (Management) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

#### Database Node
| 항목 | 최소 사양 | 권장 사양 |
|------|-----------|-----------|
| CPU | 2 Core | 4 Core |
| RAM | 4 GB | 8 GB |
| Disk | 50 GB | 200 GB (SSD) |
| Network | 1 NIC (Management) | 1 NIC (Management) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

#### Storage Node (NFS)
| 항목 | 최소 사양 | 권장 사양 |
|------|-----------|-----------|
| CPU | 2 Core | 4 Core |
| RAM | 4 GB | 8 GB |
| Disk | 200 GB | 500 GB+ (SSD/RAID) |
| Network | 1 NIC (Management) | 2 NIC (Bonding) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

#### KVM Host (Compute Node)
| 항목 | 최소 사양 | 권장 사양 |
|------|-----------|-----------|
| CPU | 4 Core (VT-x/AMD-V 지원) | 8+ Core (VT-x/AMD-V 지원) |
| RAM | 8 GB | 16 GB+ |
| Disk | 100 GB | 500 GB+ (SSD) |
| Network | **2 NIC** (Management + Public) | **2 NIC** (Management + Public) |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

> **중요**: KVM Host는 반드시 **CPU 가상화 지원** (Intel VT-x 또는 AMD-V)이 활성화되어 있어야 합니다.

### 네트워크 요구사항

CloudStack Advanced Zone은 **최소 2개의 물리적으로 분리된 네트워크**가 필요합니다:

#### 1️⃣ Management Network
- **CIDR 예시**: `10.15.0.0/24`
- **용도**: 
  - CloudStack 내부 관리 트래픽
  - Management Server ↔ Hypervisor 통신
  - Hypervisor ↔ Storage(NFS) 통신
  - Pod 내부 IP 할당
- **필요 노드**: 모든 노드 (Management, Database, Storage, KVM Hosts)

#### 2️⃣ Public Network
- **CIDR 예시**: `10.10.0.0/24`
- **용도**:
  - Guest VM의 인터넷 연결
  - Public IP 할당 (Floating IP)
  - System VM (SSVM, CPVM) 외부 통신
  - Virtual Router 외부 인터페이스
- **필요 노드**: KVM Hosts만 연결 (Management는 선택사항)

#### IP 할당 계획 예시

| 노드 | Management IP (10.15.0.0/24) | Public IP (10.10.0.0/24) |
|------|------------------------------|--------------------------|
| Management | 10.15.0.10 | - |
| Database | 10.15.0.11 | - |
| Storage (NFS) | 10.15.0.12 | - |
| KVM Host 1 | 10.15.0.101 | 10.10.0.101 |
| KVM Host 2 | 10.15.0.102 | 10.10.0.102 |
| Gateway | 10.15.0.1 | 10.10.0.1 |
| Pod IP Range | 10.15.0.200 - 10.15.0.210 | - |
| Public IP Range | - | 10.10.0.220 - 10.10.0.230 |

### 소프트웨어 요구사항

#### Ansible Controller (로컬 머신)
- Ansible 2.9 이상
- Python 3.8 이상
- SSH 접근 가능 (root 또는 sudo 권한)

#### 대상 노드
- Ubuntu 24.04 LTS (Noble Numbat)
- SSH 서버 활성화
- root 또는 sudo 권한 사용자
- 인터넷 연결 (패키지 다운로드)

### 방화벽 및 포트 요구사항

| 서비스 | 포트 | 프로토콜 | 방향 | 설명 |
|--------|------|----------|------|------|
| Management UI | 8080 | TCP | Inbound | Web UI 접근 |
| Management API | 8096 | TCP | Inbound | API 접근 |
| MySQL | 3306 | TCP | Internal | DB 접근 |
| NFS | 2049, 111 | TCP/UDP | Internal | Storage 접근 |
| Agent | 8250 | TCP | Internal | KVM Agent 통신 |
| libvirt | 16509 | TCP | Internal | VM 마이그레이션 |
| VNC Console | 5900-6100 | TCP | Inbound | VM 콘솔 접근 |

---

## Resources

CloudStack 설치 및 운영에 도움이 되는 참고 자료입니다.

### 공식 문서
- [Apache CloudStack Official Documentation](https://docs.cloudstack.apache.org/)
- [CloudStack 4.19 Installation Guide](https://docs.cloudstack.apache.org/en/4.19.0.0/installguide/)
- [CloudStack API Reference](https://cloudstack.apache.org/api/apidocs-4.19/)

### 커뮤니티
- [CloudStack Mailing Lists](https://cloudstack.apache.org/mailing-lists.html)
- [CloudStack Slack Channel](https://cloudstack.apache.org/community.html)

### 동영상 자료
<!-- 설치 가이드 동영상 링크를 여기에 추가하세요 -->
- 설치 가이드 동영상 (추가 예정)
- 네트워크 구성 가이드 (추가 예정)
- 트러블슈팅 가이드 (추가 예정)

### 유용한 도구
- [CloudMonkey CLI](https://github.com/apache/cloudstack-cloudmonkey) - CloudStack API 커맨드 라인 도구
- [Ansible Documentation](https://docs.ansible.com/) - Ansible 공식 문서

### 관련 블로그 및 튜토리얼
<!-- 관련 블로그 포스트나 튜토리얼 링크를 여기에 추가하세요 -->
- 블로그 포스트 (추가 예정)
- 심화 가이드 (추가 예정)

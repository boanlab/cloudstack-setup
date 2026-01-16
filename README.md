# CloudStack Infrastructure

<!--
- 수정사항 기록
  - 각 방화벽이나 뭔가 내용상 안맞는 것들이 너무 많음 이거 고쳐야함
  - 메인의 README의 경우에는, README에 소개, 그리고 내부 어떤 md를 참고해야하는지가 정확하게 나와있어야함.
  - 스크립트가 복잡하다고 했음 -> 스크립트는 스크립트 다워야 하는데
    - setup-ansible.sh
    - generate-ssh-copy.sh
    - 미관적인거 좋음, 근데 매 스크립트마다 다 떠야하는 것들인가. 
    - Install CloudMonkey에서 CheckSum이 Static하게 되어있는데? 
      - 그리고 불필요한 정보들을 너무 많이 띄우는 것이 아닌가? 
      - 짧게 끝날 건데 자꾸 커짐 -> 아키텍처 지원이 왜 많은거야? 
-->
## Introduction

This project automates the deployment of Apache CloudStack 4.19 private cloud infrastructure using Ansible. 

The automation handles complete installation and configuration of Management Servers, MySQL databases, KVM hypervisors, and NFS storage across distributed nodes. Network interfaces are automatically detected based on CIDR configurations, with bridge networks provisioned for Advanced Zone deployments using VXLAN isolation.

## Resources

### Project Documentation
- [Ansible CloudStack Deployment Guide](./cloudstack/README.md)
- [Installation Guide](./docs/installation.md) - Step-by-step installation guide for deploying CloudStack using this Ansible project.
- [Setup Guide](./mgmt-node/SETUP-GUIDE.md) - Instructions for configuring CloudStack Zones after installation.
- [Troubleshooting Guide](./docs/troubleshooting.md) - Common issues and solutions during installation and operation.

### Official Documentation
- [Apache CloudStack Documentation](https://docs.cloudstack.apache.org/)
- [CloudStack 4.19 Installation Guide](https://docs.cloudstack.apache.org/en/4.19.0.0/installguide/)
- [CloudStack API Reference](https://cloudstack.apache.org/api/apidocs-4.19/)
- [CloudStack Networking Guide](https://www.shapeblue.com/a-beginners-guide-to-cloudstack-networking/)

### Community
- [CloudStack GitHub Repository](https://github.com/apache/cloudstack)

---

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.


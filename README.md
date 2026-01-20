# CloudStack Setup

## Introduction

This project automates the deployment of Apache CloudStack 4.19 private cloud infrastructure using Ansible. 

The automation handles complete installation and configuration of Management Servers, MySQL databases, KVM hypervisors, and NFS storage across distributed nodes. Network interfaces are automatically detected based on CIDR configurations, with bridge networks provisioned for Advanced Zone deployments using VXLAN isolation.

## Resources

### Project Documentation
- [Ansible CloudStack Deployment Guide](./cloudstack/README.md) - CloudStack infrastructure installation guide
- [Installation Guide](./docs/installation.md) - Step-by-step installation guide for deploying CloudStack using this Ansible project.
- [Management Setup Guide](./docs/setup-guide.md) - Instructions for configuring CloudStack Zones after installation.
- [Troubleshooting Guide](./docs/troubleshooting.md) - Common issues and solutions during installation and operation.

### CloudStack Official Documentation
- [Apache CloudStack Documentation](https://docs.cloudstack.apache.org/)
- [CloudStack 4.19 Installation Guide](https://docs.cloudstack.apache.org/en/4.19.0.0/installguide/)
- [CloudStack API Reference](https://cloudstack.apache.org/api/apidocs-4.19/)
- [CloudStack Networking Guide](https://www.shapeblue.com/a-beginners-guide-to-cloudstack-networking/)

### Community
- [CloudStack GitHub Repository](https://github.com/apache/cloudstack)

---

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.


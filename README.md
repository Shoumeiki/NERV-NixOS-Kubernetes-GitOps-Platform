# NERV - Kubernetes GitOps Platform

Infrastructure-as-Code platform for automated Kubernetes deployment using NixOS, ArgoCD, and GitOps practices.

## Overview

NERV is a declarative Kubernetes platform that provides complete infrastructure automation from bare metal to GitOps-managed services. Built on NixOS for reproducible infrastructure and ArgoCD for declarative application management.

### Architecture

- **Infrastructure Layer**: NixOS configuration with K3s, MetalLB, and base services
- **Platform Layer**: ArgoCD-managed cluster services (monitoring, ingress, storage)
- **Application Layer**: GitOps-deployed workloads and applications

### Key Technologies

- [NixOS](https://nixos.org/) - Declarative Linux distribution
- [K3s](https://k3s.io/) - Lightweight Kubernetes distribution
- [ArgoCD](https://argo-cd.readthedocs.io/) - GitOps continuous delivery
- [MetalLB](https://metallb.universe.tf/) - Load balancer for bare metal
- [SOPS](https://github.com/getsops/sops) - Encrypted secrets management

## Repository Structure

```
├── infrastructure/     # NixOS infrastructure configuration
│   └── nixos/         # Flake and node configurations
├── platform/          # Platform-wide configurations
├── services/          # Infrastructure services managed by ArgoCD
├── bootstrap/         # App-of-Apps pattern root
└── docs/              # Documentation
```

## Deployment

### Prerequisites

- Target hardware with network boot capability
- Age private key for SOPS decryption
- Network access to target system

### Installation

```bash
# Prepare secrets
mkdir -p ~/secrets/var/lib/sops-nix
cp ~/.config/sops/age/keys.txt ~/secrets/var/lib/sops-nix/key.txt

# Deploy infrastructure
nixos-anywhere --extra-files ~/secrets --flake ./infrastructure/nixos#misato root@<target-ip>
```

### Post-Deployment

Access ArgoCD interface at `http://192.168.1.110` with admin credentials managed via SOPS.

## GitOps Workflow

The platform implements the App-of-Apps pattern:

1. **Bootstrap Phase**: nixos-anywhere deploys base infrastructure and ArgoCD
2. **Platform Phase**: ArgoCD synchronises platform services from Git
3. **Application Phase**: Applications deployed via GitOps workflow

All configuration changes are made via Git commits, ensuring auditability and rollback capability.

## Development

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed setup instructions and [platform/](platform/) for service configuration examples.

---

*"Don't run away."* - Rei Ayanami
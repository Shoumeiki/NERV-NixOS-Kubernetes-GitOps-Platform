# NERV - NixOS Kubernetes GitOps Platform

> A declarative, secure, and energy-efficient Kubernetes platform built with NixOS flakes and GitOps principles.

## Overview

NERV is a modern infrastructure platform that combines NixOS's declarative configuration management with Kubernetes orchestration and GitOps workflows. The project enables rapid deployment of NixOS nodes into a Kubernetes cluster with minimal manual intervention. This is a learning project and is in a lab environment.

**Key Features:**
- **One-click deployment** via NixOS-Anywhere
- **Secure by default** with SOPS-based secret management
- **GitOps-driven** cluster management
- **Energy efficient** design principles
- **Modular architecture** for easy maintenance

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Git Repository  │    │ Control Plane    │    │ Worker Nodes    │
│ (This Repo)     │───▶│ (Eva-01, etc.)   │───▶│ (Eva-00, etc.)  │
│                 │    │                  │    │                 │
│ • Flake configs │    │ • K8s Masters    │    │ • K8s Workers   │
│ • Secrets       │    │ • GitOps Engine  │    │ • Workloads     │
│ • Manifests     │    │ • Load Balancer  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Core Services

- **Container Runtime**: containerd
- **CNI**: Flannel/Cilium
- **Load Balancer**: MetalLB
- **Ingress**: Traefik
- **Storage**: Longhorn
- **DNS**: Pi-hole/Technitium
- **Monitoring**: Prometheus + Grafana
- **GitOps**: ArgoCD/Flux

## Roadmap

- [ ] Basic NixOS flake structure
- [ ] NixOS-Anywhere deployment pipeline
- [ ] SOPS secret management integration
- [ ] Core Kubernetes cluster setup
- [ ] GitOps workflow implementation
- [ ] Advanced services deployment
- [ ] Monitoring and observability
- [ ] High availability configuration

## Security

- All secrets encrypted with SOPS
- Minimal attack surface with NixOS
- Network policies enforced
- Regular security updates via flakes
- No sensitive data in repository

## License

MIT License - see LICENSE file for details.

---

*"The fate of destruction is also the joy of rebirth."* - Gendo Ikari
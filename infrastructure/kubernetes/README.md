# NERV Platform - Flux v2 GitOps Infrastructure

This directory contains the Kubernetes manifests managed by Flux v2 for the NERV platform. All infrastructure services are deployed using official Helm charts through GitOps workflows.

## Architecture

### Service Deployment Order
1. **Helm Repositories** - Chart sources for all services
2. **MetalLB** - Load balancer with IP pool 192.168.1.111-150
3. **cert-manager** - TLS certificate automation
4. **Traefik** - Ingress controller with dashboard
5. **Longhorn** - Distributed storage with management UI

### IP Allocation Strategy
```
192.168.1.100-110  │  Node Pool (Kubernetes hosts)
192.168.1.111-120  │  Core Services (DNS, Traefik, Longhorn, etc.)
192.168.1.121-150  │  Application Pool (Dynamic allocation)
```

## Service Access

| Service | IP Address | Web Dashboard | Purpose |
|---------|------------|---------------|---------|
| **DNS** | 192.168.1.111 | N/A | Network DNS resolution |
| **Traefik** | 192.168.1.112 | `http://192.168.1.112:9000` | Ingress & routing |
| **Longhorn** | 192.168.1.113 | `http://192.168.1.113` | Storage management |

## Directory Structure

```
infrastructure/kubernetes/
├── flux-system/           # Flux configuration and kustomization
├── sources/               # Helm repositories and Git sources
└── releases/              # HelmRelease definitions
    ├── metallb/          # Load balancer configuration
    ├── cert-manager/     # TLS certificate management
    ├── traefik/          # Ingress controller
    └── longhorn/         # Distributed storage
```

## 🚀 Deployment Process

Flux automatically syncs these manifests from Git every minute. All services include:
- **Official Helm charts** for better maintainability
- **Web dashboards** for visual management
- **Single-node tolerations** for control plane deployment
- **Resource limits** for efficient resource usage
- **Static IP allocation** for predictable access

## Benefits of Flux v2 Approach

- **Simplified Operations**: No complex custom NixOS modules
- **Better Maintenance**: Upstream chart updates and security patches
- **Dashboard Management**: Web UIs for all services eliminate SSH requirements
- **GitOps Native**: Declarative infrastructure with Git workflow
- **Scalability**: Proven patterns for platform engineering teams

---

*"The fate of destruction is also the joy of rebirth."* - Kaworu Nagisa
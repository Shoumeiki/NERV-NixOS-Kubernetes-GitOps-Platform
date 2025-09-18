# NERV - NixOS Kubernetes GitOps Platform

NixOS-based Kubernetes cluster with GitOps management and automated secret handling.

## Overview

Self-hosted Kubernetes platform using:
- **NixOS** for declarative system configuration
- **K3s** lightweight Kubernetes distribution
- **Flux v2** for GitOps deployment automation
- **SOPS-Nix** for encrypted secret management

## Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| OS | NixOS | Declarative system configuration |
| Kubernetes | K3s | Lightweight container orchestration |
| GitOps | Flux v2 | Automated deployment from Git |
| Load Balancer | MetalLB | LoadBalancer services on bare metal |
| Ingress | Traefik | HTTP routing and TLS termination |
| Storage | Longhorn | Distributed persistent volumes |
| Certificates | cert-manager | Automated TLS with Let's Encrypt |
| Secrets | SOPS-Nix | Encrypted secret management |

## Structure

```
infrastructure/nixos/          # NixOS configuration
├── flake.nix                 # Main system definition
├── modules/                  # Reusable configurations
│   ├── base-system.nix       # Core system setup
│   ├── users.nix             # User management
│   ├── network.nix           # Network config
│   └── services/             # Platform services
├── hosts/                    # Node-specific configs
│   └── misato/               # Example node
└── secrets/                  # SOPS-encrypted secrets

bootstrap/                    # Flux v2 bootstrap
├── root-app.yaml             # App-of-Apps definition
└── kustomization.yaml        # Kustomize config
```

## Deployment

### Bootstrap
1. Boot target system from NixOS ISO
2. Deploy with `nixos-anywhere --flake ./infrastructure/nixos#misato root@<ip>`
3. System automatically sets up K3s cluster and Flux v2
4. Flux v2 syncs platform services from Git

### GitOps Workflow
1. Make changes in Git repository
2. Flux v2 detects changes and syncs to cluster
3. Platform services update automatically
4. All changes tracked and auditable

## Development

### Local Changes
```bash
# Edit configurations
vim infrastructure/nixos/modules/services/new-service.nix

# Test locally (optional)
nixos-rebuild switch --flake ./infrastructure/nixos#misato

# Commit and push
git add . && git commit -m "add new service"
git push
```

### Adding Services
1. Create NixOS module in `infrastructure/nixos/modules/services/`
2. Import in `flake.nix`
3. Enable in host configuration
4. Push to trigger Flux v2 sync

## Access

After deployment, services are available at:
- Flux v2 UI: http://192.168.1.110
- Longhorn: http://192.168.1.111  
- Traefik: http://192.168.1.112

Default Flux v2 access: kubectl for resource management

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment guide
- [infrastructure/README.md](infrastructure/README.md) - Infrastructure details

---

*"The fate of destruction is also the joy of rebirth."* - Gendo Ikari
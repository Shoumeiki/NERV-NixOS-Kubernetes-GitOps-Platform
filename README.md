# NERV - Simplified NixOS Kubernetes GitOps Platform

Ultra-minimal, learning-focused Kubernetes platform with GitOps automation.

## Quick Start

```bash
# 1. Boot NixOS ISO on target hardware
# 2. Set root password and start SSH
passwd root && systemctl start sshd

# 3. Add GitHub token to SOPS secrets
cd infrastructure/nixos/secrets
sops secrets.yaml  # Add github.flux-token with your PAT

# 4. Deploy from development machine
nixos-anywhere --extra-files ~/secrets \
               --flake ./infrastructure/nixos#misato \
               root@<target-ip>

# 5. Flux auto-bootstraps and syncs from Git
# Access services (auto-configured via MetalLB)
kubectl get svc -A  # Find LoadBalancer IPs
```

## What You Get

| Service | Purpose | Access |
|---------|---------|---------|
| **K3s** | Kubernetes cluster | `kubectl` |
| **Flux v2** | GitOps automation | Auto-syncs from Git |
| **MetalLB** | Load balancer | Provides service IPs |
| **Traefik** | Ingress controller | HTTP routing |
| **cert-manager** | TLS certificates | Automatic HTTPS |
| **Longhorn** | Storage | Persistent volumes |
| **AdGuard Home** | DNS + ad-blocking | `adguard.nerv.local` |

## Architecture

```
Git Repository → Flux Bootstrap → Kubernetes Services
     ↓                ↓                 ↓
   Config         Auto-Sync        LoadBalancer IPs
```

**Design Philosophy:** Minimal configuration, maximum learning. Flux auto-bootstraps via `flux bootstrap github`, Helm chart defaults handle complexity.

## Deployment

Single-node cluster with essential services:
```bash
# Uses: infrastructure/kubernetes/kustomization.yaml
# MetalLB + cert-manager + Traefik + Longhorn
# ~300 lines total configuration
```

Multi-node support: Set `nerv.nodeRole.role = "worker"` in additional host configs.

## Key Simplifications

- ✅ **Flux auto-bootstrap** - Automated via `flux bootstrap github` in systemd
- ✅ **Minimal K3s flags** - Only essential: disable built-ins, kubeconfig permissions
- ✅ **Simple node roles** - Just control-plane/worker (no complex profiles)
- ✅ **No redundant config** - IP pools in MetalLB CRDs, no duplicate ConfigMaps
- ✅ **Helm defaults** - Charts handle complexity, minimal overrides

## GitOps Workflow

```bash
# Make changes
vim infrastructure/kubernetes/releases/new-service.yaml

# Commit and push
git add . && git commit -m "add service"
git push

# Flux auto-syncs within 1 minute
kubectl get helmreleases -A
```

## File Structure

```
infrastructure/
├── nixos/                    # Host configuration
│   ├── flake.nix            # System definition
│   └── modules/             # NixOS modules
└── kubernetes/              # Kubernetes manifests
    ├── kustomization.yaml   # Full platform
    ├── minimal-kustomization.yaml  # Learning mode
    └── releases/            # Service configurations
```

## Troubleshooting

```bash
# Check Flux bootstrap status
systemctl status flux-bootstrap
journalctl -u flux-bootstrap

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check Flux reconciliation
kubectl get gitrepositories,kustomizations,helmreleases -A

# View service IPs
kubectl get svc -A | grep LoadBalancer
```

## Production Migration

When ready for production, add back:
- Resource limits and requests
- Security policies and contexts
- Monitoring and alerting
- Backup strategies
- Network policies

The simplified platform provides a clean foundation for enterprise growth.

---

*"Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away."*
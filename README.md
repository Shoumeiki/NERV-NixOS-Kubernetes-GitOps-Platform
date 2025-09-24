# NERV - Simplified NixOS Kubernetes GitOps Platform

Ultra-minimal, learning-focused Kubernetes platform with GitOps automation.

## Quick Start

```bash
# 1. Boot NixOS ISO on target hardware
# 2. Set root password and start SSH
passwd root && systemctl start sshd

# 3. Deploy from development machine
nixos-anywhere --extra-files ~/secrets \
               --flake ./infrastructure/nixos#misato \
               root@<target-ip>

# 4. Access services (auto-configured via MetalLB)
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
Git Repository → Flux v2 → Kubernetes Services
     ↓              ↓           ↓
   Config        Auto-Sync   LoadBalancer IPs
```

**Design Philosophy:** Minimal configuration, maximum learning. Helm chart defaults handle complexity.

## Deployment Options

### Full Platform (Recommended)
All services with minimal configuration:
```bash
# Uses: infrastructure/kubernetes/kustomization.yaml
# ~1800 lines total configuration
```

### Ultra-Minimal (Learning)
Only MetalLB + Traefik:
```bash
# Uses: infrastructure/kubernetes/minimal-kustomization.yaml  
# ~400 lines total configuration
```

## Key Simplifications

- ✅ **No resource limits** - Kubernetes defaults work fine
- ✅ **No complex security contexts** - Learning-appropriate security
- ✅ **No verbose configurations** - Helm charts handle details
- ✅ **No hard dependencies** - Services self-heal via Kubernetes
- ✅ **Minimal ConfigMaps** - Only essential configuration

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
# Check system status
kubectl get nodes
kubectl get pods -A

# Check Flux status
kubectl get gitrepositories,helmreleases -A

# View service IPs
kubectl get svc -A | grep LoadBalancer

# Check logs
kubectl logs -n flux-system -l app=source-controller
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
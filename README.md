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

| Service | Version | Purpose | Status |
|---------|---------|---------|--------|
| **K3s** | v1.31 | Kubernetes cluster | ✅ Running |
| **Flux v2** | v2.6.1 | GitOps automation | ✅ Auto-syncing |
| **MetalLB** | v0.15.2 | Load balancer (192.168.1.111-150) | ✅ Operational |
| **Traefik** | v37.1.1 | Ingress @ 192.168.1.111 | ✅ Running |
| **cert-manager** | v1.18.2 | TLS certificates | ✅ Ready |
| **Longhorn** | v1.9.1 | Persistent storage | ✅ Running |
| **Weave GitOps** | v4.0.36 | Flux dashboard | ✅ Ready |

## Architecture

```
Git Repository → Flux Bootstrap → Kubernetes Services
     ↓                ↓                 ↓
   Config         Auto-Sync        LoadBalancer IPs
```

**Design Philosophy:** Minimal configuration, maximum learning. Flux auto-bootstraps via `flux bootstrap github`, Helm chart defaults handle complexity.

## Deployment Status

**✅ Platform Fully Operational**

Single-node cluster with all services running:
```bash
# Flux bootstrap: infrastructure/kubernetes/flux-system/
# Apps: infrastructure/kubernetes/apps/
# Config: infrastructure/kubernetes/apps/config/
# Total: ~300 lines of configuration
```

**Verified Working:**
- All 3 Flux kustomizations reconciling
- All 4 HelmReleases deployed and Ready
- Traefik LoadBalancer @ 192.168.1.111
- Dashboard: `https://traefik.nerv.local`

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
vim infrastructure/kubernetes/apps/releases/new-service.yaml

# Commit and push
git add . && git commit -m "add service"
git push

# Flux auto-syncs within 1 minute
kubectl get helmreleases -A
```

## File Structure

```
infrastructure/
├── nixos/                       # Host configuration
│   ├── flake.nix               # System definition
│   └── modules/                # NixOS modules
└── kubernetes/                 # Kubernetes manifests
    ├── flux-system/            # Flux bootstrap (managed by Flux)
    │   ├── gotk-components.yaml  # Auto-generated
    │   ├── gotk-sync.yaml        # Auto-generated
    │   └── kustomization.yaml    # Flux entry point
    ├── apps.yaml               # Apps Kustomization CRD
    └── apps/                   # Your applications
        ├── namespaces.yaml
        ├── sources/            # Helm repositories
        ├── releases/           # HelmReleases
        └── kustomization.yaml
```

## Verification & Troubleshooting

**Check Platform Health:**
```bash
# All should show READY: True
kubectl get kustomizations -n flux-system
kubectl get helmreleases -A

# All pods should be Running
kubectl get pods -A

# Get LoadBalancer IP
kubectl get svc -n traefik-system
```

**Access Services:**
```bash
# Add to /etc/hosts: 192.168.1.111 <domain>
https://traefik.nerv.local     # Traefik ingress dashboard
https://longhorn.nerv.local    # Storage management UI
https://flux.nerv.local        # GitOps dashboard (admin/admin123)
```

**Troubleshooting:**
```bash
# Check Flux bootstrap
systemctl status flux-bootstrap
journalctl -u flux-bootstrap

# Force reconciliation
flux reconcile kustomization flux-system -n flux-system
flux reconcile helmrelease <name> -n <namespace>

# Check specific resource
kubectl describe helmrelease <name> -n <namespace>
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
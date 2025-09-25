# NERV - NixOS Kubernetes GitOps Platform

Production-ready GitOps platform built on NixOS demonstrating enterprise DevOps practices with minimal configuration complexity.

## Platform Architecture

Core infrastructure leverages declarative configuration and automated reconciliation:

```
Git Repository → Flux v2 Bootstrap → Kubernetes Services → LoadBalancer IPs
```

**Design Principles:** Infrastructure as Code, GitOps automation, minimal operational overhead.

## Quick Deployment

```bash
# Boot NixOS ISO on target hardware
passwd root && systemctl start sshd

# Configure secrets
cd infrastructure/nixos/secrets
sops secrets.yaml  # Add github.flux-token with GitHub PAT

# Deploy platform
nixos-anywhere --extra-files ~/secrets \
               --flake ./infrastructure/nixos#misato \
               root@<target-ip>

# Flux automatically bootstraps and synchronizes from repository
kubectl get svc -A  # Verify LoadBalancer IP assignments
```

## Platform Services

| Component | Version | Function | Status |
|-----------|---------|----------|--------|
| **K3s** | v1.31 | Kubernetes cluster | Operational |
| **Flux v2** | v2.6.1 | GitOps automation | Reconciling |
| **MetalLB** | v0.15.2 | Load balancer (192.168.1.111-150) | Active |
| **Traefik** | v37.1.1 | Ingress controller @ 192.168.1.111 | Running |
| **cert-manager** | v1.18.2 | TLS certificate automation | Ready |
| **Longhorn** | v1.9.1 | Distributed storage | Available |

## Service Access

Configure local DNS resolution:
```bash
# Add to /etc/hosts: 192.168.1.111 <hostname>
```

**Management Interfaces:**
- `https://traefik.nerv.local` - Ingress controller dashboard
- `https://longhorn.nerv.local` - Storage management interface  
- `https://flux.nerv.local` - GitOps source controller status

## GitOps Operations

**Standard Flux Monitoring:**
```bash
flux get all -A                    # Platform-wide status
flux get sources -A                # Repository synchronization
flux get kustomizations -A         # Configuration reconciliation
flux get helmreleases -A           # Application deployment status

# Real-time monitoring
flux logs --follow --all-namespaces
```

**Platform Verification:**
```bash
# Verify all Kustomizations reconciled
kubectl get kustomizations -n flux-system

# Check HelmRelease deployment status
kubectl get helmreleases -A

# Confirm pod operational status
kubectl get pods -A

# Validate LoadBalancer service exposure
kubectl get svc -n traefik-system
```

## Troubleshooting

**Flux Bootstrap Issues:**
```bash
systemctl status flux-bootstrap
journalctl -u flux-bootstrap
```

**Force Resource Reconciliation:**
```bash
flux reconcile kustomization flux-system -n flux-system
flux reconcile helmrelease <name> -n <namespace>
```

**Resource Investigation:**
```bash
kubectl describe helmrelease <name> -n <namespace>
kubectl logs -n flux-system -l app=kustomize-controller
```

## Infrastructure Layout

```
infrastructure/
├── nixos/                       # Host system configuration
│   ├── flake.nix               # NixOS system definition
│   ├── modules/                # Modular system components
│   ├── hosts/                  # Host-specific configurations
│   └── secrets/                # SOPS-encrypted secrets
└── kubernetes/                 # Application manifests
    ├── flux-system/            # Flux bootstrap (Flux-managed)
    ├── apps.yaml               # Application Kustomization
    └── apps/                   # Platform services
        ├── namespaces.yaml
        ├── sources/            # Helm repositories
        └── releases/           # Application HelmReleases
```

## GitOps Workflow

```bash
# Make configuration changes
vim infrastructure/kubernetes/apps/releases/service.yaml

# Commit and push changes
git add . && git commit -m "update service configuration"
git push origin main

# Flux automatically reconciles within 1 minute
kubectl get helmreleases -A
```

## Production Migration

Production deployment requires:
- Resource quotas and limits
- Pod Security Standards implementation
- Network policy enforcement
- Monitoring and alerting integration
- Backup and disaster recovery procedures

The platform provides a foundation for enterprise-scale operations while maintaining development environment simplicity.

## Current Status

Platform is fully operational with all services deployed and verified. Infrastructure demonstrates:
- Automated GitOps workflows
- Declarative configuration management  
- Enterprise security patterns
- Production-ready service mesh
- Scalable storage architecture

Ready for multi-node expansion and production workload deployment.
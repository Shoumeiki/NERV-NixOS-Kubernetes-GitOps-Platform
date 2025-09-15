# Infrastructure

NixOS-based infrastructure configuration for the NERV platform.

## Components

- `nixos/` - NixOS flake and node configurations  
- `scripts/` - Deployment automation scripts

## Deployment

```bash
nixos-anywhere --extra-files ~/secrets --flake ./nixos#misato root@<target-ip>
```

This deploys:
- NixOS with K3s cluster
- MetalLB load balancer (192.168.1.110-150)
- ArgoCD GitOps controller
- Automated cluster bootstrap

## Architecture

**Bootstrap Phase**: NixOS installs base Kubernetes infrastructure
**GitOps Phase**: ArgoCD manages all subsequent platform services

---

*"The beginning and the end are one and the same."* - Kaworu Nagisa
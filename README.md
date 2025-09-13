# NERV - NixOS Kubernetes GitOps Platform

> NixOS-based Kubernetes cluster with automated deployment and GitOps management.

## Overview

Automated NixOS cluster deployment using nixos-anywhere, SOPS secret management, and declarative disk partitioning. Built for learning DevOps/K8s in a home lab environment.

**Features:**
- Automated deployment via nixos-anywhere
- SOPS-encrypted secrets
- Declarative disk management with Btrfs
- Modular NixOS configurations

## Current Status

**Phase 1: Foundation** ✅
- [x] Modular NixOS flake structure
- [x] Global configuration for all cluster nodes
- [x] Hardware-specific node configurations (Misato)
- [x] Btrfs subvolumes for disk management
- [x] SSH hardening and power management
- [x] SOPS secret management during boot
- [x] Automated deployment with nixos-anywhere
- [x] SSH key and password authentication

**Future Phases**
- [ ] Kubernetes cluster setup
- [ ] GitOps workflow implementation
- [ ] Service deployment (Home Assistant, etc.)
- [ ] Monitoring and logging
- [ ] High availability setup

## Quick Start

```bash
# Validate configuration
nix flake check

# Test build locally
nixos-rebuild build --flake .#misato

# Deploy to remote host
nixos-anywhere --flake .#misato root@<target-ip>
```

## Deployment

See **[DEPLOYMENT.md](DEPLOYMENT.md)** for full deployment instructions including:
- Hardware preparation and requirements
- Secret management with SOPS
- Step-by-step nixos-anywhere deployment
- Troubleshooting and recovery procedures

**Quick deployment checklist**:
- Target hardware booted from NixOS ISO
- Age private key available (`~/.config/sops/age/keys.txt`)
- Configuration validated (`nix flake check`)
- Network connectivity to target
- Age key prepared: `mkdir -p /tmp/secrets/var/lib/sops-nix && cp ~/.config/sops/age/keys.txt /tmp/secrets/var/lib/sops-nix/key.txt`
- **Deploy**: `nixos-anywhere --extra-files /tmp/secrets --flake .#<node> root@<ip>`

---

*"The fate of destruction is also the joy of rebirth."* - Gendo Ikari
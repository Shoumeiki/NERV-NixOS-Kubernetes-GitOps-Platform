# NERV - NixOS Kubernetes GitOps Platform

> A declarative, secure, and energy-efficient Kubernetes platform built with NixOS flakes and GitOps principles.

## Overview

NERV is a modern infrastructure platform that combines NixOS's declarative configuration management with Kubernetes orchestration and GitOps workflows. The project enables rapid deployment of NixOS nodes into a Kubernetes cluster with minimal manual intervention. This is a learning project and is in a lab environment.

**Planned Features:**
- **One-click deployment** via NixOS-Anywhere
- **Secure by default** with SOPS-based secret management
- **GitOps-driven** cluster management
- **Energy efficient** design principles
- **Modular architecture** for easy maintenance

## Current Status

**Phase 1: Foundation** ✅
- [x] NixOS flake structure with modular architecture
- [x] Global configuration for all cluster nodes
- [x] Hardware-specific node configurations (Misato)
- [x] Declarative disk management with Btrfs subvolumes
- [x] Production-ready security and power management

**Next Phase: Deployment**
- [ ] SOPS secret management integration
- [ ] NixOS-Anywhere deployment pipeline
- [ ] SSH key management and authentication

**Future Phases**
- [ ] Core Kubernetes cluster setup
- [ ] GitOps workflow implementation
- [ ] Advanced services deployment
- [ ] Monitoring and observability
- [ ] High availability configuration

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

Ready to deploy? See **[DEPLOYMENT.md](DEPLOYMENT.md)** for complete deployment instructions including:
- Hardware preparation and requirements
- Secret management with SOPS
- Step-by-step nixos-anywhere deployment
- Troubleshooting and recovery procedures

**Quick deployment checklist**:
- ✅ Target hardware booted from NixOS ISO
- ✅ Age private key available (`~/.config/sops/age/keys.txt`)
- ✅ Configuration validated (`nix flake check`)
- ✅ Network connectivity to target
- 🚀 Ready to deploy: `nixos-anywhere --flake .#misato root@<ip>`

---

*"The fate of destruction is also the joy of rebirth."* - Gendo Ikari
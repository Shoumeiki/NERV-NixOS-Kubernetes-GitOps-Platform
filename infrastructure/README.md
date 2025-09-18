# NERV Infrastructure

NixOS-based infrastructure layer providing declarative system configuration for the Kubernetes platform.

## Overview

This layer uses NixOS flakes to define:
- System configuration and hardening
- Kubernetes cluster setup (K3s)
- Platform services (Flux v2, MetalLB, etc.)
- Secret management with SOPS-Nix

## Structure

```
infrastructure/nixos/
├── flake.nix                 # Main system definition
├── modules/                  # Reusable configurations
│   ├── base-system.nix       # Core system setup
│   ├── users.nix             # User management
│   ├── network.nix           # Network config
│   └── services/             # Platform services
│       ├── flux-system.nix
│       ├── metallb.nix
│       ├── traefik-simple.nix
│       ├── cert-manager-simple.nix
│       └── longhorn-simple.nix
├── hosts/                    # Node-specific configs
│   └── misato/               # Example node
└── secrets/                  # SOPS-encrypted secrets
    ├── secrets.yaml
    └── .sops.yaml
```

## Deployment

Deploy complete infrastructure with one command:

```bash
nixos-anywhere --extra-files ~/secrets \
               --flake ./nixos#misato \
               root@<target-ip>
```

This command:
1. Partitions and installs NixOS on target hardware
2. Sets up K3s cluster with platform services
3. Configures Flux v2 to sync from Git repository
4. Deploys encrypted secrets via SOPS-Nix

Verify deployment:
```bash
ssh admin@<ip> 'kubectl get nodes'
curl http://192.168.1.110  # Flux v2 dashboard
```

## Network Configuration

| Service | IP Address | Purpose |
|---------|------------|---------|
| Flux v2 | 192.168.1.110 | GitOps dashboard |
| Longhorn | 192.168.1.111 | Storage UI |
| Traefik | 192.168.1.112 | Ingress dashboard |
| Pool | 192.168.1.110-115 | LoadBalancer IPs |

## Security

- SSH key authentication only
- Firewall with minimal open ports
- SOPS-encrypted secrets
- Non-root user with sudo access
- Kubernetes RBAC enabled

## Customization

### Adding Nodes
1. Copy `hosts/misato/` to `hosts/<new-node>/`
2. Customize hardware and network settings
3. Deploy with `nixos-anywhere --flake ./nixos#<new-node> root@<ip>`

### Managing Secrets
```bash
# Edit secrets
sops infrastructure/nixos/secrets/secrets.yaml

# Add new secret
sops --set '["key"] "value"' secrets.yaml
```

## Troubleshooting

Common issues and solutions:

```bash
# Check system status
journalctl -u k3s -f

# Verify Flux v2
kubectl get pods -n flux-system

# Test secret decryption
sops -d secrets/secrets.yaml

# Monitor resources
kubectl top nodes
```

---

*"The beginning and the end are one and the same."* - Kaworu Nagisa
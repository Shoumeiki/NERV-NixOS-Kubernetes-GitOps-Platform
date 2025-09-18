# Deployment Guide

Instructions for deploying the NERV platform from bare metal to operational cluster.

## Overview

Single-command deployment using nixos-anywhere:
- Partitions and installs NixOS
- Sets up K3s cluster
- Deploys platform services via Flux v2
- Configures encrypted secrets

## Prerequisites

Install required tools:

```bash
# Core deployment tools
nix profile install github:nix-community/nixos-anywhere
nix profile install nixpkgs#age nixpkgs#sops

# Or use development shell
cd infrastructure/nixos && nix develop
```

## Deployment Steps

### 1. Prepare Target System
1. Boot target from NixOS ISO
2. Set root password: `passwd root`
3. Start SSH: `systemctl start sshd`
4. Note IP address: `ip addr show`

### 2. Configure Secrets
```bash
# Verify age key exists
ls ~/.config/sops/age/keys.txt

# Test secret decryption
sops -d infrastructure/nixos/secrets/secrets.yaml

# Prepare secret transfer
mkdir -p ~/secrets/var/lib/sops-nix
cp ~/.config/sops/age/keys.txt ~/secrets/var/lib/sops-nix/key.txt
chmod 600 ~/secrets/var/lib/sops-nix/key.txt
```

### 3. Deploy
```bash
nixos-anywhere --extra-files ~/secrets \
               --flake ./infrastructure/nixos#misato \
               root@<target-ip>
```

### 4. Verify
```bash
# SSH access
ssh admin@<target-ip>

# Cluster status  
kubectl get nodes
kubectl get pods -A

# Service access
curl http://192.168.1.110  # Flux v2 dashboard
curl http://192.168.1.111  # Longhorn  
curl http://192.168.1.112  # Traefik

# Check Flux v2 status
kubectl get gitrepositories,helmreleases -A
```

## Troubleshooting

### Common Issues

**SOPS key not found**:
```bash
# Check key location
ls -la ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Verify decryption
sops -d infrastructure/nixos/secrets/secrets.yaml
```

**SSH connection refused**:
- Wait 2-3 minutes for boot to complete
- Check SSH service: `systemctl status sshd`
- Verify network: `ip addr show`

**Flux v2 dashboard not accessible**:
```bash
# Check MetalLB config
kubectl get configmap -n metallb-system config -o yaml

# Verify service IPs
kubectl get svc -n flux-system
```

**Disk partitioning fails**:
```bash
# Check available disks
lsblk -f

# Verify disko config matches hardware
cat infrastructure/nixos/hosts/misato/disko.nix
```

## Recovery

### Complete Redeployment
1. Boot target from NixOS ISO
2. Clear existing installation: `wipefs -af /dev/sda` (destroys all data)
3. Retry with debug: `nixos-anywhere --debug --extra-files ~/secrets --flake ./infrastructure/nixos#misato root@<ip>`

### Partial Recovery
```bash
# Rebuild configuration only
nixos-rebuild switch --flake ./infrastructure/nixos#misato

# Restart services
systemctl restart k3s
systemctl restart sops-nix
```

## Security Notes

- Never commit age private keys to Git
- Deploy on trusted networks only  
- SSH uses key authentication only
- Rotate age keys regularly
- Administrative access limited to `admin` user
- RBAC enforced for all services

---

*"Only those who have lost everything can understand true strength."* - Misato Katsuragi
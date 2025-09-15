# Deployment Guide

Complete deployment instructions for NERV platform infrastructure.

## Prerequisites

### Development Environment

Required tools for deployment:

```bash
# Install nixos-anywhere
nix profile install github:nix-community/nixos-anywhere

# Install secret management tools
nix profile install nixpkgs#age nixpkgs#sops
```

### Target Hardware

- x86_64 architecture with UEFI support
- Network connectivity
- Minimum 4GB RAM, 32GB storage

## Deployment Process

### Target Preparation

1. Boot target system from NixOS ISO
2. Configure temporary root access:
   ```bash
   passwd root
   ```
3. Note target IP address:
   ```bash
   ip addr show
   ```

### Environment Setup

1. Clone repository:
   ```bash
   git clone <repository-url>
   cd NERV-NixOS-Kubernetes-GitOps-Platform
   ```

2. Verify SOPS configuration:
   ```bash
   ls ~/.config/sops/age/keys.txt
   sops -d infrastructure/nixos/secrets/secrets.yaml
   ```

3. Validate configuration:
   ```bash
   nix flake check infrastructure/nixos
   nixos-rebuild build --flake infrastructure/nixos#misato
   ```

### Deployment Execution

1. Prepare secrets for transfer:
   ```bash
   mkdir -p ~/secrets/var/lib/sops-nix
   cp ~/.config/sops/age/keys.txt ~/secrets/var/lib/sops-nix/key.txt
   chmod 600 ~/secrets/var/lib/sops-nix/key.txt
   ```

2. Execute deployment:
   ```bash
   nixos-anywhere --extra-files ~/secrets --flake ./infrastructure/nixos#misato root@<target-ip>
   ```

The deployment process will:
- Partition storage according to disko configuration
- Install NixOS with specified configuration
- Configure SOPS secret decryption
- Initialize K3s cluster with ArgoCD and MetalLB
- Establish GitOps workflow

### Post-Deployment Verification

1. Connect to deployed system:
   ```bash
   ssh ellen@<target-ip>
   ```

2. Verify core services:
   ```bash
   systemctl status k3s
   kubectl get nodes
   kubectl get pods -n argocd
   ```

3. Access ArgoCD interface at `http://192.168.1.110`

## Troubleshooting

### Secret Management Issues

**SOPS key not found:**
```bash
# Verify key location and permissions
ls -la ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

**Secret decryption failure:**
```bash
# Check service logs on target
journalctl -u sops-nix.service
```

### Network Connectivity

**SSH connection refused:**
- Verify target system boot completion
- Check SSH service status: `systemctl status sshd`
- Confirm firewall configuration

**ArgoCD interface inaccessible:**
- Verify MetalLB configuration: `kubectl get svc -n metallb-system`
- Check LoadBalancer IP assignment: `kubectl get svc -n argocd`

### Storage Configuration

**Disk partitioning failure:**
- Verify target storage device in disko configuration
- Check for existing partition schemes that may conflict

### Recovery Procedures

1. Reboot target to NixOS ISO for retry
2. Use debug flag for detailed output:
   ```bash
   nixos-anywhere --debug --flake ./infrastructure/nixos#misato root@<target-ip>
   ```

## Security Considerations

- Age private keys must not be committed to version control
- Deploy only on trusted network segments
- SSH access restricted to key-based authentication

---

*"Only those who have lost everything can understand true strength."* - Misato Katsuragi
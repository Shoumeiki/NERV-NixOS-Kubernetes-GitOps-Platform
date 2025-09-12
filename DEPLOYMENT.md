# NERV Deployment Guide

This guide covers deploying NERV nodes to real hardware using nixos-anywhere with encrypted secrets.

## Prerequisites

### On Your Development Machine

1. **Install Required Tools**:
   ```bash
   # Install nixos-anywhere (if not in nix develop shell)
   nix profile install github:nix-community/nixos-anywhere
   
   # Ensure age and sops are available
   nix profile install nixpkgs#age nixpkgs#sops
   ```

2. **Access to Target Hardware**:
   - Intel N150 Mini PC (or compatible x86_64 hardware)
   - Network access to the target machine
   - UEFI boot capability

## Deployment Process

### Step 1: Prepare Target Hardware

1. **Boot target machine from NixOS ISO**:
   - Download NixOS minimal ISO
   - Create bootable USB drive
   - Boot target machine and ensure network connectivity

2. **Set root password on target** (temporary, for initial access):
   ```bash
   # On the target machine console
   sudo passwd root
   ```

3. **Find target IP address**:
   ```bash
   # On target machine
   ip addr show
   ```

### Step 2: Prepare Deployment Environment

1. **Clone repository**:
   ```bash
   git clone git@github.com:Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git
   cd NERV-NixOS-Kubernetes-GitOps-Platform/nixos
   ```

2. **Ensure age private key is available**:
   ```bash
   # Verify your age key exists (created during setup)
   ls -la ~/.config/sops/age/keys.txt
   
   # Test decryption works
   sops -d secrets/secrets.yaml
   ```

3. **Validate configuration**:
   ```bash
   # Check flake validity
   nix flake check
   
   # Test build (optional but recommended)
   nixos-rebuild build --flake .#misato
   ```

### Step 3: Deploy to Target

1. **Deploy with nixos-anywhere**:
   ```bash
   nixos-anywhere --flake .#misato root@<TARGET_IP>
   ```

   This command will:
   - Connect to the target machine via SSH
   - Partition and format disks according to `disko.nix`
   - Install NixOS with your configuration
   - Copy the age private key for secret decryption
   - Reboot into the new system

### Step 4: Verify Deployment

1. **Wait for reboot** (2-3 minutes)

2. **Connect as Ellen**:
   ```bash
   # Test SSH key authentication
   ssh ellen@<TARGET_IP>
   
   # If SSH keys aren't working yet, password should work
   # Password is the one you encrypted in secrets.yaml
   ```

3. **Verify secrets deployment**:
   ```bash
   # On the target machine as Ellen
   sudo systemctl status deploy-ellen-ssh-keys.service
   ls -la ~/.ssh/authorized_keys
   ```

4. **Test system functionality**:
   ```bash
   # Check system status
   systemctl status
   
   # Verify disk layout
   df -h
   lsblk
   
   # Check services
   systemctl status sshd
   ```

## Troubleshooting

### Common Issues

1. **Age key not found during deployment**:
   ```bash
   # Ensure key exists and is readable
   ls -la ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

2. **SSH connection refused after deployment**:
   - Wait longer for boot (Intel N150 can be slow)
   - Check SSH service: `systemctl status sshd` on target
   - Verify firewall: `nix-shell -p nmap --run "nmap -p 22 <TARGET_IP>"`

3. **Secret deployment failed**:
   ```bash
   # On target, check service logs
   journalctl -u deploy-ellen-ssh-keys.service
   journalctl -u sops-nix.service
   ```

4. **Disk partitioning issues**:
   - Ensure target disk is `/dev/nvme0n1` or update `disko.nix`
   - Check for existing partitions that might interfere

### Recovery

If deployment fails, you can:

1. **Reboot target to NixOS ISO** and try again
2. **Check logs** with `--debug` flag:
   ```bash
   nixos-anywhere --debug --flake .#misato root@<TARGET_IP>
   ```

## Security Notes

- **Private keys**: Never commit your age private key to git
- **SSH access**: After successful deployment, consider disabling password auth
- **Network**: Deploy on trusted networks or use VPN access

## Next Steps

After successful deployment:
1. Disable SSH password authentication
2. Set up monitoring and logging
3. Configure additional services
4. Add more nodes to the cluster

---

*"The fate of destruction is also the joy of rebirth."* - Gendo Ikari
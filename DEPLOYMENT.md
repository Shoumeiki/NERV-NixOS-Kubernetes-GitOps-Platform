# NERV Platform Deployment Guide
*Enterprise Infrastructure Deployment Procedures*

---

## **Overview**

This guide provides comprehensive instructions for deploying the NERV NixOS Kubernetes GitOps Platform from bare metal to fully operational cluster. The deployment process emphasizes **automation**, **security**, and **reproducibility** through infrastructure-as-code principles.

**Deployment Characteristics**:
- **Single Command Deployment**: Complete infrastructure from one command
- **Secure by Default**: Encrypted secrets and hardened configurations
- **Fully Automated**: No manual configuration steps required
- **Production Ready**: Enterprise-grade security and monitoring

---

## **Prerequisites**

### **Development Environment Setup**

Required tools for deployment automation:

```bash
# Core NixOS deployment tooling
nix profile install github:nix-community/nixos-anywhere

# Secret management stack
nix profile install nixpkgs#age nixpkgs#sops

# Optional: Development shell with all tools included
cd infrastructure/nixos && nix develop
```

### **Target Hardware Requirements**

| Requirement | Minimum | Recommended | Purpose |
|-------------|---------|-------------|---------|
| **Architecture** | x86_64 | x86_64 | NixOS and container compatibility |
| **Boot** | UEFI | UEFI | Modern boot security features |
| **Memory** | 4GB | 8GB+ | Kubernetes + applications |
| **Storage** | 32GB SSD | 256GB+ SSD | System + container images + volumes |
| **Network** | Ethernet | Gigabit Ethernet | Cluster communication and external access |

---

## **Deployment Process**

### **Phase 1: Target System Preparation**

1. **Boot Target from NixOS ISO**
   ```bash
   # Download latest NixOS ISO
   curl -L https://releases.nixos.org/nixos/25.05/nixos-25.05/nixos-minimal-25.05-x86_64-linux.iso

   # Create bootable media and boot target system
   ```

2. **Enable SSH Access**
   ```bash
   # Set temporary root password
   passwd root

   # Start SSH daemon
   systemctl start sshd
   ```

3. **Identify Network Configuration**
   ```bash
   # Note target IP address for deployment
   ip addr show
   # Example output: inet 192.168.1.100/24 brd 192.168.1.255 scope global eth0
   ```

### **Phase 2: Infrastructure Configuration**

1. **Clone Platform Repository**
   ```bash
   git clone https://github.com/Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git
   cd NERV-NixOS-Kubernetes-GitOps-Platform
   ```

2. **Configure Secret Management**
   ```bash
   # Verify age private key exists
   ls ~/.config/sops/age/keys.txt

   # Test secret decryption capability
   sops -d infrastructure/nixos/secrets/secrets.yaml

   # Should display decrypted secrets without errors
   ```

3. **Validate Configuration**
   ```bash
   # Enter development environment
   cd infrastructure/nixos && nix develop

   # Validate all configurations
   nix flake check

   # Test build configuration locally (optional)
   nixos-rebuild build --flake .#misato
   ```

### **Phase 3: Automated Deployment**

1. **Prepare Secret Transfer**
   ```bash
   # Create secure secret transfer directory
   mkdir -p ~/secrets/var/lib/sops-nix
   cp ~/.config/sops/age/keys.txt ~/secrets/var/lib/sops-nix/key.txt
   chmod 600 ~/secrets/var/lib/sops-nix/key.txt

   # Verify secret file integrity
   file ~/secrets/var/lib/sops-nix/key.txt
   ```

2. **Execute One-Command Deployment**
   ```bash
   nixos-anywhere --extra-files ~/secrets \
                  --flake ./infrastructure/nixos#misato \
                  root@<target-ip>
   ```

### **Deployment Process Overview**

The automated deployment performs these operations **in sequence**:

| Phase | Duration | Operations |
|-------|----------|------------|
| **System Preparation** | 2-3 min | Disk partitioning, filesystem creation |
| **NixOS Installation** | 5-8 min | Base system + packages installation |
| **Security Configuration** | 1-2 min | User creation, SSH hardening, secret decryption |
| **Kubernetes Bootstrap** | 3-5 min | K3s cluster initialization |
| **Platform Services** | 2-4 min | ArgoCD, MetalLB, ingress, storage |
| **GitOps Activation** | 1-2 min | Repository connection, synchronization |

**Total Deployment Time**: Approximately **10-15 minutes** for complete infrastructure

### **Phase 4: Post-Deployment Verification**

**Enterprise Validation Checklist**:

1. **System Connectivity Verification**
   ```bash
   # Connect with administrative user credentials
   ssh ellen@<target-ip>

   # Verify system identity and uptime
   hostname && uptime
   ```

2. **Core Platform Service Health**
   ```bash
   # Kubernetes cluster status
   systemctl status k3s
   kubectl get nodes -o wide
   kubectl cluster-info

   # Verify all system pods are running
   kubectl get pods --all-namespaces

   # Check ArgoCD deployment status
   kubectl get pods -n argocd
   kubectl get svc -n argocd
   ```

3. **GitOps Platform Access**
   ```bash
   # ArgoCD web interface: http://192.168.1.110
   # Initial admin password retrieval:
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath="{.data.password}" | base64 -d
   ```

4. **Storage and Network Validation**
   ```bash
   # Longhorn distributed storage: http://192.168.1.111
   kubectl get pods -n longhorn-system

   # Traefik ingress controller: http://192.168.1.112
   kubectl get pods -n traefik

   # MetalLB load balancer status
   kubectl get pods -n metallb-system
   ```

---

## **Troubleshooting Guide**

### **Secret Management Issues**

**SOPS Age Key Not Found**:
```bash
# Verify age key location and permissions
ls -la ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Test secret decryption capability
sops -d infrastructure/nixos/secrets/secrets.yaml
```

**Secret Decryption Failure on Target**:
```bash
# Check SOPS-nix service status
journalctl -u sops-nix -f

# Verify age key deployment
ls -la /var/lib/sops-nix/key.txt
```

### **Network Connectivity Issues**

**SSH Connection Refused**:
- Wait for complete system boot (2-3 minutes)
- Check SSH service: `systemctl status sshd`
- Verify network configuration: `ip addr show`
- Test from known working client

**ArgoCD Interface Inaccessible**:
```bash
# Verify MetalLB LoadBalancer configuration
kubectl get configmap -n metallb-system config -o yaml

# Check service IP allocation
kubectl get svc -n argocd argocd-server

# Validate ingress configuration
kubectl get ingress --all-namespaces
```

### **Storage Configuration Problems**

**Disk Partitioning Failure**:
```bash
# List available storage devices
lsblk -f

# Check for existing partition conflicts
fdisk -l /dev/sda

# Verify disko configuration matches hardware
cat infrastructure/nixos/hosts/misato/disko.nix
```

**Longhorn Storage Issues**:
```bash
# Check required kernel modules
lsmod | grep -E "(iscsi|nfs|dm_)"

# Verify storage prerequisites
ls -la /var/lib/longhorn
```

### **Service Deployment Problems**

**ArgoCD Application Sync Failures**:
```bash
# Check repository connectivity
kubectl logs -n argocd deployment/argocd-repo-server

# Verify application status
kubectl get applications -n argocd

# Manual sync trigger (if needed)
argocd app sync root-app
```

---

## **Recovery Procedures**

### **Complete Redeployment**
1. **Boot target system from NixOS ISO**
2. **Clear any existing installations**:
   ```bash
   # CAUTION: This destroys all data on target disk
   wipefs -af /dev/sda
   ```
3. **Retry deployment with debug logging**:
   ```bash
   nixos-anywhere --debug \
                  --extra-files ~/secrets \
                  --flake ./infrastructure/nixos#misato \
                  root@<target-ip>
   ```

### **Partial Recovery Options**
```bash
# Rebuild NixOS configuration only
nixos-rebuild switch --flake ./infrastructure/nixos#misato

# Restart specific services
systemctl restart k3s
systemctl restart sops-nix
```

---

## **Security Considerations**

### **Deployment Security**
- **Age private keys**: Never commit to version control or transmit unencrypted
- **Network isolation**: Deploy on trusted network segments only
- **SSH hardening**: Key-based authentication enforced, password login disabled
- **Secret rotation**: Regularly rotate age keys and regenerate encrypted secrets

### **Operational Security**
- **Administrative access**: Limited to `ellen` user with sudo privileges
- **Service accounts**: Kubernetes RBAC enforced for all platform services
- **Network policies**: Default deny with explicit allow rules for required communication
- **Audit logging**: Comprehensive logging enabled for security monitoring

---

*"Only those who have lost everything can understand true strength."* - Misato Katsuragi
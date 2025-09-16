# infrastructure/nixos/hosts/common/secrets.nix
#
# SOPS Secret Management Configuration - Enterprise Credential Security
#
# LEARNING OBJECTIVE: This module demonstrates production-grade secret management
# using SOPS (Secrets OPerationS) with age encryption. Key learning areas:
#
# 1. ENCRYPTED SECRET STORAGE: Git-native encrypted configuration management
# 2. DECLARATIVE CREDENTIALS: Infrastructure secrets defined as code
# 3. ACCESS CONTROL: Fine-grained permissions and ownership for sensitive data
# 4. DEPLOYMENT SECURITY: Secure credential injection during system bootstrap
#
# WHY SOPS FOR SECRET MANAGEMENT:
# - Secrets encrypted at rest in Git repositories (compliance requirement)
# - Age encryption provides modern cryptographic security (vs legacy PGP)
# - Declarative secret definitions integrate with NixOS configuration
# - Fine-grained access control prevents credential leakage
#
# ENTERPRISE SECURITY PATTERN: This configuration establishes encrypted
# credential management suitable for compliance environments (SOC2, HIPAA)
# while maintaining GitOps workflow integration and operational efficiency.

{ config, ... }:

{
  sops = {
    # ENCRYPTED SECRET SOURCE: Central location for all platform credentials
    defaultSopsFile = ../../secrets/secrets.yaml;

    # AGE DECRYPTION KEY: Private key location for secret decryption
    # Deployed to target systems via nixos-anywhere --extra-files
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # CREDENTIAL DEFINITIONS: Platform secrets with strict access controls
    secrets = {
      # USER AUTHENTICATION: Administrative user password hash
      "ellen/hashedPassword" = {
        neededForUsers = true;        # Required during user account creation
        name = "ellen-hashedPassword";
        owner = "root";               # Root ownership for security
        group = "root";
        mode = "0400";                # Read-only for root user only
      };

      # SSH ACCESS CONTROL: Administrative user SSH public key
      "ellen/sshKey" = {
        name = "ellen-sshKey";
        owner = "root";
        group = "root";
        mode = "0444";                # Read-only for deployment script access
      };

      # KUBERNETES CLUSTER SECURITY: K3s cluster join token
      "k3s/token" = {
        name = "k3s-token";
        owner = "root";
        group = "root";
        mode = "0400";                # Highly sensitive - root access only
      };

      # GITOPS PLATFORM ACCESS: ArgoCD administrative credentials
      "argocd/adminPassword" = {
        name = "argocd-admin-password";
        owner = "root";
        group = "root";
        mode = "0400";                # Administrative access control
      };

      # FUTURE SECRET PLACEHOLDERS: Prepared for additional platform services
      # "monitoring/grafanaAdminPassword" = { ... };
      # "backup/encryptionKey" = { ... };
      # "tls/wildcardCert" = { ... };
    };
  };
}
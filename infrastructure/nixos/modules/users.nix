# modules/users.nix
#
# User Account Management - Enterprise Identity and Access Management
#
# LEARNING OBJECTIVE: This module demonstrates enterprise-grade user management
# and SSH security hardening for server infrastructure. Key learning areas:
#
# 1. SECURE AUTHENTICATION: SSH key-based authentication with password disable
# 2. PRIVILEGE ESCALATION: Controlled sudo access with password requirements
# 3. SECRET MANAGEMENT: SOPS integration for encrypted credential storage
# 4. ACCESS CONTROL: Minimal user privileges following principle of least privilege
#
# WHY SECURE USER MANAGEMENT MATTERS:
# - Password authentication vulnerable to brute force attacks
# - SSH keys provide cryptographic authentication superior to passwords
# - Root access restrictions prevent accidental system damage
# - Audit trails enable tracking of administrative actions
#
# ENTERPRISE PATTERN: This configuration establishes security baselines
# suitable for compliance requirements (SOC2, ISO 27001) while maintaining
# operational efficiency for infrastructure administration.

{ config, pkgs, lib, ... }:

with lib;

{
  options.nerv.users = {
    adminUser = mkOption {
      type = types.str;
      default = "ellen";
      description = ''
        Primary administrative user account name for system administration.
      '';
    };
  };

  config = {
    # ADMINISTRATIVE USER ACCOUNT: Dedicated non-root user with controlled privileges
    users.users.${config.nerv.users.adminUser} = {
      isNormalUser = true;                     # Standard user account, not system user
      description = "Ellen - NERV Operations Director";

      # GROUP MEMBERSHIPS: Minimal required privileges for infrastructure administration
      extraGroups = [
        "wheel"              # sudo access for administrative tasks
        "networkmanager"     # network configuration management
        "systemd-journal"    # system log access for troubleshooting
      ];

      # SECURE PASSWORD STORAGE: SOPS-encrypted password hash
      hashedPasswordFile = config.sops.secrets."ellen/hashedPassword".path;
    };

    # SSH SECURITY HARDENING: Enterprise-grade remote access configuration
    services.openssh = {
      enable = true;
      settings = {
        # AUTHENTICATION SECURITY: Disable password authentication to prevent brute force
        PasswordAuthentication = false;        # Force key-based authentication only
        PermitRootLogin = "no";               # Prevent direct root access via SSH
        X11Forwarding = false;                # Disable X11 forwarding (not needed for servers)

        # ACCESS CONTROL: Restrict SSH access to specific users
        AllowUsers = [ config.nerv.users.adminUser ];  # Only allow designated admin user
      };
      ports = [ 22 ];                         # Standard SSH port (consider changing for security)
    };

    # AUTOMATED SSH KEY DEPLOYMENT: Secure key management via SOPS integration
    systemd.services.deploy-ellen-ssh-keys = {
      description = "Deploy Ellen's SSH keys from SOPS";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];         # Wait for SOPS-Nix secret decryption
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Deploy SSH public key from encrypted SOPS secret to user's authorized_keys
        ExecStart = "${pkgs.bash}/bin/bash ${../hosts/common/scripts/deploy-ssh-keys.sh} ${config.sops.secrets."ellen/sshKey".path}";
      };
    };

    # PRIVILEGE ESCALATION CONTROL: Secure sudo configuration
    security.sudo = {
      enable = true;
      wheelNeedsPassword = true;              # Require password for sudo operations (defense in depth)
    };
  };
}
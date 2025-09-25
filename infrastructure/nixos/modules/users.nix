# File: infrastructure/nixos/modules/users.nix
# Description: Secure user management with SOPS integration and SSH configuration
# Learning Focus: User account management, SSH hardening, and systemd service creation

{ config, pkgs, lib, ... }:

with lib;

{
  options.nerv.users = {
    adminUser = mkOption {
      type = types.str;
      default = "ellen";
      description = "Primary administrative user account name";
    };
  };

  config = {
    # Create admin user with encrypted password from SOPS
    users.users.${config.nerv.users.adminUser} = {
      isNormalUser = true;
      description = "Ellen - NERV Operations Director";
      extraGroups = [ "wheel" "networkmanager" "systemd-journal" ];
      hashedPasswordFile = config.sops.secrets."ellen/hashedPassword".path;
    };

    # Configure hardened SSH service with key-only authentication
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;  # Force key-based authentication
        PermitRootLogin = "no";          # Disable root login
        X11Forwarding = false;           # Disable X11 forwarding
        AllowUsers = [ config.nerv.users.adminUser ];  # Restrict to admin user only
        MaxAuthTries = 3;                # Limit authentication attempts
        ClientAliveInterval = 300;       # Send keepalive every 5 minutes
        ClientAliveCountMax = 2;         # Disconnect after 2 failed keepalives
        Protocol = "2";                  # Force SSH protocol version 2
        PermitEmptyPasswords = false;    # Explicitly disable empty passwords
        PubkeyAuthentication = true;     # Explicitly enable pubkey auth
        AuthenticationMethods = "publickey";  # Only allow pubkey authentication
      };
      ports = [ 22 ];
    };

    # Custom systemd service to deploy SSH keys from encrypted storage
    systemd.services.deploy-ellen-ssh-keys = {
      description = "Deploy Ellen's SSH keys from SOPS";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];  # Wait for SOPS to decrypt secrets
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${../hosts/common/scripts/deploy-ssh-keys.sh} ${config.sops.secrets."ellen/sshKey".path}";
      };
    };

    security.sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };
}
# modules/users.nix
# User account management for NERV platform

{ config, pkgs, lib, ... }:

with lib;

{
  options.nerv.users = {
    adminUser = mkOption {
      type = types.str;
      default = "ellen";
      description = "Primary administrative user account";
    };
  };

  config = {
    # Administrative user configuration  
    users.users.${config.nerv.users.adminUser} = {
      isNormalUser = true;
      description = "Ellen - NERV Operations Director";
      extraGroups = [ "wheel" "networkmanager" "systemd-journal" ];
      hashedPasswordFile = config.sops.secrets."ellen/hashedPassword".path;
    };

    # SSH configuration with security hardening
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = false;
        AllowUsers = [ config.nerv.users.adminUser ];
      };
      ports = [ 22 ];
    };

    # Deploy SSH keys via SOPS
    systemd.services.deploy-ellen-ssh-keys = {
      description = "Deploy Ellen's SSH keys from SOPS";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${../hosts/common/scripts/deploy-ssh-keys.sh} ${config.sops.secrets."ellen/sshKey".path}";
      };
    };

    # Sudo configuration
    security.sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };
}
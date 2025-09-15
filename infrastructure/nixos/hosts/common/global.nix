# infrastructure/nixos/hosts/common/global.nix
# Global configuration for all cluster nodes

{ config, pkgs, lib, ... }:

{
  imports = [
    ./secrets.nix
  ];
  # NixOS release compatibility
  system.stateVersion = "25.05";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" "btrfs" ];
  };

  networking = {
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowPing = true;
    };
  };

  time.timeZone = "Australia/Melbourne";
  i18n.defaultLocale = "en_AU.UTF-8";

  environment.systemPackages = with pkgs; [
    htop btop tree curl wget rsync
    dig nmap traceroute
    fd ripgrep eza
    kubectl neovim
  ];

  # Administrative user configuration
  users.users.ellen = {
    isNormalUser = true;
    description = "Ellen - NERV Operations Director";

    extraGroups = [ "wheel" "networkmanager" "systemd-journal" ];
    hashedPasswordFile = config.sops.secrets."ellen/hashedPassword".path;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowUsers = [ "ellen" ];
    };
    ports = [ 22 ];
  };
  systemd.services.deploy-ellen-ssh-keys = {
    description = "Deploy Ellen's SSH keys from SOPS";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/deploy-ssh-keys.sh} ${config.sops.secrets."ellen/sshKey".path}";
    };
  };

  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };

  services = {
    timesyncd.enable = true;
    journald.extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFiles=5
    '';
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}

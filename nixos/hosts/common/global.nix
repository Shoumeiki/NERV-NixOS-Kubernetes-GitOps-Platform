# hosts/common/global.nix
# Global configuration for all cluster nodes

{ config, pkgs, lib, ... }:

{
  imports = [
    ./secrets.nix
  ];
  # NixOS release compatibility - don't change after initial deployment
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
    # Monitoring
    htop
    btop
    tree
    curl
    wget
    rsync

    # Network tools
    dig
    nmap
    traceroute

    # File tools
    fd
    ripgrep
    eza

    # Kubernetes tools
    kubectl

    neovim
  ];

  # Administrative user configuration
  users.users.ellen = {
    isNormalUser = true;
    description = "Ellen - NERV Operations Director";

    extraGroups = [
      "wheel"           # sudo access
      "networkmanager"
      "systemd-journal"
    ];

    # Password hash from SOPS
    hashedPasswordFile = config.sops.secrets."ellen/hashedPassword".path;

    # SSH keys handled by systemd service (SOPS timing issue)
  };

  # SSH service configuration
  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = false;  # keys only
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowUsers = [ "ellen" ];
    };

    ports = [ 22 ];
  };

  # SSH key deployment via systemd service
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

    # Limit log disk usage
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

    # Weekly cleanup
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}

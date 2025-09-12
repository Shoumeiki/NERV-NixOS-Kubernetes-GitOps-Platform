# hosts/common/global.nix
# NERV Cluster - Global Configuration
#
# Shared configuration applied to all nodes in the NERV cluster.
# These settings ensure consistency and provide baseline functionality
# that every node requires regardless of its specific role.

{ config, pkgs, lib, ... }:

{
  imports = [
    ./secrets.nix
  ];
  # NixOS release compatibility - don't change after initial deployment
  system.stateVersion = "25.05";

  # Boot and system initialization
  boot = {
    # UEFI boot configuration for modern hardware
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Filesystem support for various storage devices
    supportedFilesystems = [ "ntfs" "btrfs" ];
  };

  # Network configuration and security
  networking = {
    # DNS servers for reliable name resolution
    nameservers = [ "1.1.1.1" "8.8.8.8" ];

    # Network management for headless operation
    networkmanager.enable = true;

    # Basic firewall with diagnostic access
    firewall = {
      enable = true;
      allowPing = true;
    };
  };

  # Localization and time settings
  time.timeZone = "Australia/Melbourne";
  i18n.defaultLocale = "en_AU.UTF-8";

  # Essential system packages for all nodes
  environment.systemPackages = with pkgs; [
    # System monitoring and administration
    htop
    btop
    tree
    curl
    wget
    rsync

    # Network diagnostics and troubleshooting
    dig
    nmap
    traceroute

    # File management and search
    fd
    ripgrep
    eza

    # Text editing for configuration management
    neovim
  ];

  # Administrative user configuration
  users.users.ellen = {
    isNormalUser = true;
    description = "Ellen - NERV Operations Director";

    # Administrative privileges
    extraGroups = [
      "wheel"           # Sudo access for system administration
      "networkmanager"  # Network configuration access
      "systemd-journal" # System log access
    ];

    # Authentication configuration - using SOPS secrets
    hashedPasswordFile = config.sops.secrets."ellen/hashedPassword".path;

    # SSH public key access - using SOPS secrets
    # Note: keyFiles expects files to exist at evaluation time
    # We'll handle SSH keys via the sshd service configuration instead
  };

  # SSH service configuration
  services.openssh = {
    enable = true;

    # Security hardening settings
    settings = {
      PasswordAuthentication = true;  # TODO: Disable once SSH keys working
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowUsers = [ "ellen" ];
    };

    ports = [ 22 ];
  };

  # SSH key deployment via systemd service (load-order safe)
  systemd.services.deploy-ellen-ssh-keys = {
    description = "Deploy Ellen's SSH keys from SOPS";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Create Ellen's .ssh directory
      mkdir -p /home/ellen/.ssh
      chown ellen:users /home/ellen/.ssh
      chmod 700 /home/ellen/.ssh

      # Copy SSH keys from SOPS secret
      cp ${config.sops.secrets."ellen/sshKeys".path} /home/ellen/.ssh/authorized_keys
      chown ellen:users /home/ellen/.ssh/authorized_keys
      chmod 600 /home/ellen/.ssh/authorized_keys
    '';
  };

  # System security configuration
  security = {
    # Sudo configuration for administrative access
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };

  # Core system services
  services = {
    # Network time synchronization for cluster coordination
    timesyncd.enable = true;

    # System log management
    journald.extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFiles=5
    '';

    # TODO: Consider automatic updates for production
    # system-update.enable = true;
  };

  # Nix package manager configuration
  nix = {
    # Enable flakes and modern Nix commands
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };

    # Automated maintenance to prevent disk space issues
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}

# hosts/common/global.nix
# Global configuration shared by all NERV hosts
# This file contains settings that every node needs regardless of its role

{ config, pkgs, lib, ... }:

{
  # System basics
  system.stateVersion = "25.05"; # Don't change this after initial install

  # Boot configuration
  boot = {
    # Use systemd-boot for UEFI systems (modern and simple)
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Enable support for NTFS (useful for USB drives, etc.)
    supportedFilesystems = [ "ntfs" ];
  };

  # Networking fundamentals
  networking = {
    # We'll set hostnames per-host, but configure DNS here
    nameservers = [ "1.1.1.1" "8.8.8.8" ];  # Cloudflare + Google DNS

    # Enable NetworkManager for easier network management
    networkmanager.enable = true;

    # Basic firewall - we'll open specific ports per host as needed
    firewall = {
      enable = true;
      allowPing = true;  # Allow ping for network diagnostics
    };
  };

  # Time and localisation
  time.timeZone = "Australia/Melbourne";  # Adjust to your timezone
  i18n.defaultLocale = "en_AU.UTF-8";     # Australian English

  # Essential system packages available on all hosts
  environment.systemPackages = with pkgs; [
    # System administration
    htop
    btop
    tree
    curl
    wget
    rsync

    # Network diagnostics
    dig
    nmap
    traceroute

    # File management
    fd
    ripgrep
    eza

    # Text editing
    neovim
  ];

  # Ellen - our administrative user across all hosts
  users.users.ellen = {
    isNormalUser = true;
    description = "Ellen - NERV Operations Director";

    # Administrative groups
    extraGroups = [
      "wheel"         # sudo access
      "networkmanager" # network configuration
      "systemd-journal" # log access
    ];

    # For now, we'll use password authentication
    # TODO: Replace with SSH key authentication via secrets management
    hashedPassword = "$6$rounds=500000$your-hashed-password-here";

    # Enable SSH access
    openssh.authorizedKeys.keys = [
      # TODO: Add Ellen's SSH public keys here
    ];
  };

  # SSH configuration
  services.openssh = {
    enable = true;

    # Security hardening
    settings = {
      PasswordAuthentication = true; # TODO: Disable once SSH keys working
      PermitRootLogin = "no";
      X11Forwarding = false;

      # Only allow Ellen to SSH in
      AllowUsers = [ "ellen" ];
    };

    # Listen on standard port
    ports = [ 22 ];
  };

  # System security hardening
  security = {
    # Enable sudo for wheel group members
    sudo = {
      enable = true;
      wheelNeedsPassword = true;  # Require password for sudo
    };

    # Additional kernel hardening
    kernelModules = [ ];  # Blacklist unnecessary modules if needed
  };

  # System services that every host needs
  services = {
    # Network time synchronisation
    timesyncd.enable = true;

    # Automatic system updates (conservative approach)
    # TODO: Consider if we want this for production
    # system-update.enable = true;
  };

  # Nix configuration
  nix = {
    # Enable flakes system-wide
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # Optimise storage by hard-linking identical files
      auto-optimise-store = true;
    };

    # Automatic garbage collection to save disk space
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # System monitoring and logging
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    SystemMaxFiles=5
  '';
}
# modules/base-system.nix
# Base system configuration for NERV platform nodes

{ config, pkgs, lib, ... }:

{
  # System compatibility
  system.stateVersion = "25.05";

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" "btrfs" ];
  };

  # Network configuration
  networking = {
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowPing = true;
    };
  };

  # Locale and timezone
  time.timeZone = "Australia/Melbourne";
  i18n.defaultLocale = "en_AU.UTF-8";

  environment.systemPackages = with pkgs; [
    htop btop tree curl wget rsync
    dig nmap traceroute
    fd ripgrep eza
    kubectl neovim
  ];

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
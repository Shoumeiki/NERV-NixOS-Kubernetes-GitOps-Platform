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

  # Longhorn path requirements for NixOS
  environment.etc."longhorn-paths".text = ''
    # Make critical binaries available to Longhorn containers
    mount.nfs=${pkgs.nfs-utils}/bin/mount.nfs
    umount.nfs=${pkgs.nfs-utils}/bin/umount.nfs
    iscsiadm=${pkgs.openiscsi}/bin/iscsiadm
    cryptsetup=${pkgs.cryptsetup}/bin/cryptsetup
    mkfs.ext4=${pkgs.e2fsprogs}/bin/mkfs.ext4
    mkfs.xfs=${pkgs.xfsprogs}/bin/mkfs.xfs
  '';

  environment.systemPackages = with pkgs; [
    htop btop tree curl wget rsync
    dig nmap traceroute
    fd ripgrep eza
    kubectl neovim
    # Storage dependencies for Longhorn
    openiscsi        # iSCSI client tools (correct nixpkgs name)
    util-linux
    nfs-utils        # NFSv4 client for RWX volumes and backups
    cryptsetup       # For encrypted volumes
    xfsprogs         # XFS filesystem tools
    e2fsprogs        # ext4 filesystem tools
    parted           # Disk partitioning tools
    lvm2             # Logical volume management
  ];

  services = {
    timesyncd.enable = true;
    journald.extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFiles=5
    '';
    
    # iSCSI service required for Longhorn
    openiscsi = {
      enable = true;
      name = "iqn.2016-04.com.open-iscsi:${config.networking.hostName}";
    };
    
    # NFS client service for Longhorn RWX volumes and backups
    rpcbind.enable = true;  # Required for NFS
    
    # LVM service for Longhorn volume management
    lvm.enable = true;
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
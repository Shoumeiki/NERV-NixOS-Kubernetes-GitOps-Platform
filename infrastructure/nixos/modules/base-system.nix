# File: infrastructure/nixos/modules/base-system.nix
# Description: Base system configuration for NERV platform nodes
# Learning Focus: NixOS hardening and Kubernetes host prerequisites

{ config, pkgs, lib, ... }:

{
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
      # SSH access
      allowedTCPPorts = [ 22 ];
      # K3s cluster communication
      allowedTCPPortRanges = [
        { from = 6443; to = 6443; }  # K3s API server
        { from = 10250; to = 10250; } # Kubelet API
        { from = 2379; to = 2380; }   # etcd client/peer
      ];
      # K3s flannel VXLAN
      allowedUDPPorts = [ 8472 ];
      # MetalLB L2 mode
      allowedTCPPortRanges = [
        { from = 7946; to = 7946; }  # MetalLB memberlist
      ];
      allowedUDPPortRanges = [
        { from = 7946; to = 7946; }  # MetalLB memberlist
      ];
    };
  };

  time.timeZone = "Australia/Melbourne";
  i18n.defaultLocale = "en_AU.UTF-8";

  # NixOS compatibility fixes for Kubernetes storage drivers
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];
  
  virtualisation.docker.logDriver = "json-file";

  # Binary path mapping for Longhorn CSI driver
  environment.etc."longhorn-paths".text = ''
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
    openiscsi util-linux nfs-utils cryptsetup
    xfsprogs e2fsprogs parted lvm2
  ];

  services = {
    timesyncd.enable = true;

    journald.extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFiles=5
    '';

    openiscsi = {
      enable = true;
      name = "iqn.2016-04.com.open-iscsi:${config.networking.hostName}";
    };

    rpcbind.enable = true;
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
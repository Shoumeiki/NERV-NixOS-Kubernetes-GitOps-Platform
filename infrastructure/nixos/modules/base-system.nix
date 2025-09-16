# modules/base-system.nix
# Base system configuration for NERV platform nodes
#
# LEARNING OBJECTIVE: This module demonstrates enterprise-grade NixOS system
# configuration that balances security, reliability, and Kubernetes compatibility.
# Key learning areas:
#
# 1. SYSTEM HARDENING: Proper service configuration and resource limits
# 2. KUBERNETES INTEGRATION: Host-level prerequisites for K8s workloads
# 3. STORAGE READINESS: NixOS-specific fixes for Longhorn CSI driver
# 4. OPERATIONAL FOUNDATION: Logging, time sync, and system maintenance
#
# WHY THESE CONFIGURATIONS MATTER:
# - NixOS requires special consideration for container runtimes and storage
# - Kubernetes storage drivers expect traditional FHS paths not available in NixOS
# - Enterprise environments need predictable system behavior and audit trails
# - Resource constraints on edge hardware require careful service tuning

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

  # CRITICAL NixOS COMPATIBILITY: Longhorn storage driver integration
  # Longhorn expects traditional Linux FHS paths that don't exist in NixOS
  # These fixes bridge the gap between NixOS's unique filesystem and K8s expectations
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];
  # JSON logging format required for proper log aggregation in K8s environments
  virtualisation.docker.logDriver = "json-file";

  # STORAGE DRIVER COMPATIBILITY: Essential binary path mapping for Longhorn
  # NixOS stores binaries in /nix/store paths, but Longhorn containers need
  # predictable locations. This configuration creates the bridge.
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
    # SYSTEM MONITORING: Essential tools for cluster node observability
    htop btop tree curl wget rsync

    # NETWORK DIAGNOSTICS: Critical for K8s networking troubleshooting
    dig nmap traceroute

    # MODERN CLI TOOLS: Enhanced productivity for system administration
    fd ripgrep eza  # Modern replacements for find, grep, ls
    kubectl neovim  # Kubernetes management and configuration editing

    # STORAGE SUBSYSTEM: Complete Longhorn CSI driver support stack
    # These packages provide the storage primitives that Longhorn requires
    # for enterprise-grade persistent volumes in Kubernetes
    openiscsi        # iSCSI client tools (correct nixpkgs name)
    util-linux       # Core system utilities for filesystem operations
    nfs-utils        # NFSv4 client for RWX volumes and backup storage
    cryptsetup       # LUKS encryption for secure volume storage
    xfsprogs         # XFS filesystem tools (high-performance option)
    e2fsprogs        # ext4 filesystem tools (compatibility standard)
    parted           # Disk partitioning and management
    lvm2             # Logical volume management for dynamic storage
  ];

  services = {
    # ENTERPRISE TIME SYNCHRONIZATION: Critical for distributed K8s operations
    # Kubernetes requires accurate time across all nodes for:
    # - Certificate validation, API token expiry, log correlation
    timesyncd.enable = true;

    # LOG MANAGEMENT: Prevents disk exhaustion on resource-constrained hardware
    # Production clusters generate significant log volume - these limits prevent
    # storage exhaustion while maintaining adequate audit trail
    journald.extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFiles=5
    '';

    # STORAGE PROTOCOL SERVICES: Essential for Longhorn's multi-protocol support

    # iSCSI service enables block storage over IP for high-performance volumes
    openiscsi = {
      enable = true;
      name = "iqn.2016-04.com.open-iscsi:${config.networking.hostName}";
    };

    # NFS client enables shared storage (ReadWriteMany) for applications
    # requiring concurrent access from multiple pods
    rpcbind.enable = true;  # RPC binding service required for NFS protocol

    # LVM provides dynamic volume provisioning and snapshot capabilities
    # Essential for Longhorn's advanced storage features
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
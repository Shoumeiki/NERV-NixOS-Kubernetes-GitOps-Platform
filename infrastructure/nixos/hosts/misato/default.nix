# File: infrastructure/nixos/hosts/misato/default.nix
# Description: Primary Kubernetes control plane node with Intel hardware optimization
# Learning Focus: Hardware-specific configuration, K3s setup, and GitOps bootstrapping

{ config, pkgs, lib, ... }:

{
  imports = [ ./disko.nix ];  # Import disk configuration

  # Basic networking configuration for control plane node
  networking = {
    hostName = "misato";
    useDHCP = lib.mkDefault true;
    wireless.enable = false;
  };

  # Configure node role for Kubernetes cluster management
  nerv.nodeRole = {
    role = "control-plane";      # Primary cluster management node
    hardwareProfile = "mini-pc";  # Intel N150 mini PC optimization
    storage = {
      allowScheduling = true;      # Allow Longhorn storage scheduling
      tier = "standard";
    };
    compute = {
      allowWorkloads = true;       # Allow general workloads on control plane
      maxPods = 100;               # Reasonable pod limit for mini PC
    };
  };

  # Boot configuration optimized for Intel N150 and Kubernetes workloads
  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };

    kernelModules = [
      "kvm-intel"   # Intel virtualization support
      "iscsi_tcp"   # iSCSI storage protocol
      "nfs"         # Network file system
      "nfsd"        # NFS daemon
      "dm_crypt"    # Device mapper encryption
      "dm_mod"      # Device mapper core
    ];

    extraModulePackages = [ ];
    kernelParams = [ "i915.enable_guc=2" ];  # Enable Intel GuC firmware

    # System tuning for Kubernetes performance
    kernel.sysctl = {
      "fs.file-max" = 2097152;          # Increase file descriptor limit
      "net.core.rmem_max" = 134217728;  # Increase network buffer sizes
      "net.core.wmem_max" = 134217728;
      # Additional Kubernetes optimizations
      "fs.inotify.max_user_watches" = 524288;      # Support more file watches
      "fs.inotify.max_user_instances" = 512;       # Support more inotify instances
      "net.core.netdev_max_backlog" = 30000;       # Network performance
      "net.ipv4.tcp_max_syn_backlog" = 8096;       # TCP connection optimization
      "vm.max_map_count" = 262144;                 # Memory mapping for containers
    };
  };

  # Intel N150 hardware optimization
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver      # Intel media acceleration
        libvdpau-va-gl         # Video acceleration API
        intel-compute-runtime  # OpenCL runtime
        level-zero             # Intel GPU compute API
      ];
    };

    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = false;  # Disable unused Bluetooth
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "powersave";
  };

  services = {
    thermald.enable = true;
    # K3s Kubernetes distribution configuration
    k3s = {
      enable = true;
      role = "server";       # Control plane node
      clusterInit = true;    # Initialize new cluster
      tokenFile = config.sops.secrets."k3s/token".path;  # Encrypted cluster token
      extraFlags = toString ([
        "--disable=traefik"   # Use external Traefik via GitOps
        "--disable=servicelb" # Use MetalLB via GitOps
        "--disable=local-storage" # Use Longhorn for storage
        # Performance optimizations for single-node cluster
        "--kube-apiserver-arg=max-requests-inflight=400"
        "--kube-apiserver-arg=max-mutating-requests-inflight=200" 
        "--kube-controller-manager-arg=node-monitor-period=2s"
        "--kube-controller-manager-arg=node-monitor-grace-period=16s"
        "--kubelet-arg=max-pods=110"
        "--kubelet-arg=cluster-dns=10.43.0.10"
        "--write-kubeconfig-mode=644"
      ] ++ (lib.mapAttrsToList (key: value: "--node-label=${key}=${value}") config.nerv.nodeRole.nodeLabels));
    };

    xserver.enable = false;
    printing.enable = false;
    pipewire.enable = false;
    avahi.enable = false;
    udisks2.enable = false;
    power-profiles-daemon.enable = false;
  };

  # GitOps configuration with Flux CD
  nerv = {
    flux = {
      enable = true;
      repository = {
        url = config.nerv.network.repository.url;  # GitHub repository URL
        branch = "main";
        path = "infrastructure/kubernetes";         # Kubernetes manifests path
      };
      namespace = "flux-system";                   # Flux installation namespace
      interval = "1m";                            # Git polling interval
    };
  };

  # System service configuration for cluster operations
  systemd = {
    services = {
      setup-ellen-kubeconfig = {
        description = "Setup kubectl access for Ellen";
        wantedBy = [ "multi-user.target" ];
        after = [ "k3s.service" ];  # Wait for K3s to start
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash ${../common/scripts/setup-kubeconfig.sh}";
        };
      };
    };

    # Prevent sleep modes for server reliability
    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';

    # Faster service startup/shutdown for development
    extraConfig = ''
      DefaultTimeoutStopSec=30s
      DefaultTimeoutStartSec=30s
    '';
  };
}
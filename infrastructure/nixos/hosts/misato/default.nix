# infrastructure/nixos/hosts/misato/default.nix
#
# NERV Control Plane Node - "Misato" (Intel N150 Mini PC)
#
# LEARNING OBJECTIVE: This host configuration demonstrates enterprise-grade
# single-node Kubernetes cluster setup optimized for edge computing environments.
# Key learning areas:
#
# 1. HARDWARE OPTIMIZATION: Intel N150 specific kernel modules and performance tuning
# 2. CONTROL PLANE CONFIG: Single-node cluster with workload scheduling capabilities
# 3. STORAGE INTEGRATION: Longhorn-compatible kernel modules and system preparation
# 4. BOOTSTRAP AUTOMATION: Systematic service initialization and dependency management
#
# WHY SINGLE-NODE CONTROL PLANE CONFIGURATION:
# - Edge computing scenarios often require infrastructure consolidation
# - Mini PC hardware provides sufficient compute for development/homelab use
# - Demonstrates understanding of Kubernetes node roles and scheduling constraints
# - Cost-effective alternative to multi-node clusters for learning and development
#
# ENTERPRISE PATTERN: Even single-node deployments benefit from proper role
# definition, resource management, and automated bootstrap procedures that scale
# to multi-node architectures.

{ config, pkgs, lib, ... }:

{
  imports = [ ./disko.nix ];

  # NODE IDENTITY: Evangelion-themed naming for memorable infrastructure
  # Misato Katsuragi - Operations Director, appropriate for control plane node
  networking = {
    hostName = "misato";
    useDHCP = lib.mkDefault false;   # Static IP for infrastructure stability
    wireless.enable = false;         # Wired connection for stability and security

    # STATIC IP CONFIGURATION: Reserved node pool range 192.168.1.100-110
    # This ensures consistent network identity for infrastructure nodes
    interfaces.eth0 = {
      ipv4.addresses = [{
        address = "192.168.1.100";
        prefixLength = 24;
      }];
    };

    # NETWORK GATEWAY AND DNS: Standard home lab configuration
    defaultGateway = "192.168.1.1";
    nameservers = [ "192.168.1.2" "8.8.8.8" ];
  };

  # KUBERNETES NODE ROLE: Scalable architecture planning for future expansion
  # Even single-node clusters benefit from explicit role definition
  nerv.nodeRole = {
    role = "control-plane";
    hardwareProfile = "mini-pc";
    storage = {
      allowScheduling = true;  # Allow Longhorn on control plane for single-node
      tier = "standard";
    };
    compute = {
      allowWorkloads = true;   # Allow workloads on control plane for single-node
      maxPods = 100;
    };
  };

  # BOOT AND KERNEL CONFIGURATION: Optimized for Intel N150 and Kubernetes workloads
  boot = {
    # HARDWARE INITIALIZATION: Essential drivers for Intel N150 Mini PC
    initrd = {
      # Core hardware support modules loaded during boot
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };

    # RUNTIME KERNEL MODULES: Support for virtualization and distributed storage
    kernelModules = [
      "kvm-intel"          # Intel virtualization for container efficiency

      # LONGHORN STORAGE REQUIREMENTS: Essential modules for distributed storage
      "iscsi_tcp"          # iSCSI over TCP for block storage replication
      "nfs"                # NFS client for shared storage (ReadWriteMany volumes)
      "nfsd"               # NFS server for backup storage and multi-access
      "dm_crypt"           # Device mapper encryption for secure volumes
      "dm_mod"             # Device mapper core for volume abstraction
    ];

    extraModulePackages = [ ];

    # INTEL GRAPHICS OPTIMIZATION: Enable GuC (Graphics Micro Controller) firmware
    # Improves GPU efficiency and reduces CPU overhead for hardware acceleration
    kernelParams = [ "i915.enable_guc=2" ];

    # SYSTEM PERFORMANCE TUNING: Optimized for Kubernetes and storage workloads
    kernel.sysctl = {
      "fs.file-max" = 2097152;           # Increase file descriptor limit for containers
      "net.core.rmem_max" = 134217728;   # Increase network receive buffer (128MB)
      "net.core.wmem_max" = 134217728;   # Increase network send buffer (128MB)
    };
  };

  # HARDWARE ACCELERATION: Intel N150 graphics and compute optimization
  hardware = {
    # INTEL GRAPHICS STACK: Modern video acceleration and compute capabilities
    graphics = {
      enable = true;
      enable32Bit = true;        # Support for legacy 32-bit applications
      extraPackages = with pkgs; [
        intel-media-driver       # VA-API driver for hardware video acceleration
        libvdpau-va-gl           # VDPAU to VA-API bridge for compatibility
        intel-compute-runtime    # OpenCL runtime for GPU compute workloads
        level-zero               # Intel's low-level GPU API for high-performance computing
      ];
    };

    # CPU OPTIMIZATION: Intel microcode updates for security and stability
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;  # Allow proprietary firmware for full functionality

    # DISABLE UNUSED HARDWARE: Reduce attack surface and power consumption
    bluetooth.enable = false;              # No Bluetooth needed for server workloads
  };

  # POWER MANAGEMENT: Optimized for 24/7 server operation with efficiency focus
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "powersave";  # Balance performance vs power consumption
  };

  # SYSTEM SERVICES: Core platform services and Kubernetes cluster configuration
  services = {
    # THERMAL MANAGEMENT: Intel thermald for automatic thermal protection
    thermald.enable = true;
    # KUBERNETES CONTROL PLANE: K3s server configuration for single-node cluster
    k3s = {
      enable = true;
      role = "server";                                    # Control plane node
      clusterInit = true;                                 # Initialize new cluster
      tokenFile = config.sops.secrets."k3s/token".path;   # Secure cluster join token

      # CLUSTER CUSTOMIZATION: Disable built-in components for custom implementations
      extraFlags = toString ([
        "--disable=traefik"     # Use our enterprise Traefik configuration
        "--disable=servicelb"   # Use MetalLB for production-grade load balancing
      ] ++ (lib.mapAttrsToList (key: value: "--node-label=${key}=${value}") config.nerv.nodeRole.nodeLabels));
    };

    # NERV PLATFORM SERVICES: Flux v2 GitOps-managed infrastructure stack
    nerv = {
      # GITOPS FOUNDATION: Flux v2 for declarative infrastructure management
      flux = {
        enable = true;
        repository = {
          url = config.nerv.network.repository.url;
          branch = "main";
          path = "infrastructure/kubernetes";
        };
        namespace = "flux-system";
        interval = "1m";
      };

      # NOTE: All other services (MetalLB, Traefik, cert-manager, Longhorn) are now
      # managed through Flux v2 GitOps using official Helm charts. This provides:
      # - Better maintainability with upstream chart updates
      # - Reduced complexity in NixOS configuration
      # - Standardized deployment patterns
      # - Web UI access for all services (dashboard management)
      #
      # Services will be automatically deployed via:
      # - infrastructure/kubernetes/releases/metallb/
      # - infrastructure/kubernetes/releases/traefik/
      # - infrastructure/kubernetes/releases/cert-manager/
      # - infrastructure/kubernetes/releases/longhorn/
    };

    # DISABLE DESKTOP SERVICES: Optimize for headless server operation
    xserver.enable = false;                    # No X11 GUI needed
    printing.enable = false;                   # No printer support needed
    pipewire.enable = false;                   # No audio services needed
    avahi.enable = false;                      # No mDNS/Bonjour needed
    udisks2.enable = false;                    # No removable media mounting
    power-profiles-daemon.enable = false;      # Manual power management
  };

  # NERV PLATFORM SERVICES: Flux v2 GitOps-managed infrastructure stack
  nerv = {
    # GITOPS FOUNDATION: Flux v2 for declarative infrastructure management
    flux = {
      enable = true;
      repository = {
        url = config.nerv.network.repository.url;
        branch = "main";
        path = "infrastructure/kubernetes";
      };
      namespace = "flux-system";
      interval = "1m";
    };

    # NOTE: All other services (MetalLB, Traefik, cert-manager, Longhorn) are now
    # managed through Flux v2 GitOps using official Helm charts. This provides:
    # - Better maintainability with upstream chart updates
    # - Reduced complexity in NixOS configuration
    # - Standardized deployment patterns
    # - Web UI access for all services (dashboard management)
    #
    # Services will be automatically deployed via:
    # - infrastructure/kubernetes/releases/metallb/
    # - infrastructure/kubernetes/releases/traefik/
    # - infrastructure/kubernetes/releases/cert-manager/
    # - infrastructure/kubernetes/releases/longhorn/
  };

  # SYSTEMD AUTOMATION: Bootstrap services for cluster initialization
  systemd = {
    services = {
      # USER ACCESS SETUP: Configure kubectl access for administrative user
      setup-ellen-kubeconfig = {
        description = "Setup kubectl access for Ellen";
        wantedBy = [ "multi-user.target" ];
        after = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash ${../common/scripts/setup-kubeconfig.sh}";
        };
      };

      # NOTE: GitOps bootstrap is now handled declaratively through the ArgoCD
      # enterprise module. The root application and all platform services are
      # deployed automatically via the NixOS configuration system, eliminating
      # the need for imperative bootstrap scripts.
    };

    # POWER MANAGEMENT: Prevent sleep states for 24/7 server operation
    sleep.extraConfig = ''
      AllowSuspend=no         # Disable system suspend - server must stay active
      AllowHibernation=no     # Disable hibernation - not suitable for servers
    '';

    # SERVICE TIMING: Optimized timeouts for faster boot and shutdown
    extraConfig = ''
      DefaultTimeoutStopSec=30s    # Faster service shutdown (default 90s)
      DefaultTimeoutStartSec=30s   # Faster service startup (default 90s)
    '';
  };
}
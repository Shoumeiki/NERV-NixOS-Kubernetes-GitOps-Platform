# hosts/misato/default.nix
# NERV Node - Misato Configuration
#
# Hardware-specific configuration for Misato (Intel N150 Mini PC)
# Optimized for 24/7 headless operation as a Kubernetes cluster node
# with focus on energy efficiency and reliable performance.

{ config, pkgs, lib, ... }:

{
  imports = [
    # Declarative disk configuration
    ./disko.nix
    # Hardware scan results will be added here after initial deployment
    # ./hardware-configuration.nix
  ];

  # Network configuration
  networking = {
    hostName = "misato";

    # DHCP configuration for initial setup
    useDHCP = lib.mkDefault true;

    # Disable wireless capabilities for power efficiency
    wireless.enable = false;
  };

  # Boot and kernel configuration
  boot = {
    # Storage device drivers for Intel N150 hardware
    initrd = {
      availableKernelModules = [
        "xhci_pci"      # USB 3.0 controller support
        "ahci"          # SATA controller support
        "nvme"          # NVMe storage support
        "usb_storage"   # USB storage devices
        "sd_mod"        # SD card reader support
      ];
      kernelModules = [ ];
    };

    # Virtualization and container support
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];

    # Intel N150 hardware optimization
    kernelParams = [
      "i915.enable_guc=2"  # Enable Intel GPU GuC/HuC firmware
      # "mitigations=off"  # Uncomment for better performance if security allows
    ];

    # System tuning for server workloads
    kernel.sysctl = {
      "fs.file-max" = 2097152;          # Increased file descriptor limits
      "net.core.rmem_max" = 134217728;  # Network buffer optimization
      "net.core.wmem_max" = 134217728;
    };
  };

  # Hardware acceleration and graphics
  hardware = {
    # Intel graphics acceleration for compute workloads
    graphics = {
      enable = true;
      enable32Bit = true;

      # Intel GPU drivers and compute runtime
      extraPackages = with pkgs; [
        intel-media-driver    # Modern Intel GPU driver
        libvdpau-va-gl        # VDPAU via VA-API support
        intel-compute-runtime # OpenCL runtime for AI/compute
        level-zero            # Intel GPU compute API
      ];
    };

    # CPU microcode and firmware
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    # Disable unused hardware for power savings
    bluetooth.enable = false;
  };

  # Power management for 24/7 operation
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "powersave";
  };

  # System services configuration
  services = {
    # Intel thermal management
    thermald.enable = true;

    # Disable desktop-oriented services
    xserver.enable = false;
    printing.enable = false;
    pipewire.enable = false;
    avahi.enable = false;
    udisks2.enable = false;
    power-profiles-daemon.enable = false;
  };

  # System daemon optimization
  systemd = {
    # Disable sleep states for server operation
    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';

    # Faster boot and shutdown times
    extraConfig = ''
      DefaultTimeoutStopSec=30s
      DefaultTimeoutStartSec=30s
    '';
  };
}
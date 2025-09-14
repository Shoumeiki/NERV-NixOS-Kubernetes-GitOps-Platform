# hosts/misato/default.nix
# Misato node configuration (Intel N150 Mini PC)

{ config, pkgs, lib, ... }:

{
  imports = [
    ./disko.nix
    # ./hardware-configuration.nix  # Added after deployment
  ];

  networking = {
    hostName = "misato";
    useDHCP = lib.mkDefault true;
    wireless.enable = false;  # Wired connection only
  };

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"      # USB 3.0
        "ahci"          # SATA
        "nvme"          # NVMe storage
        "usb_storage"
        "sd_mod"        # SD card reader
      ];
      kernelModules = [ ];
    };

    kernelModules = [ "kvm-intel" ];  # Virtualization support
    extraModulePackages = [ ];

    kernelParams = [
      "i915.enable_guc=2"  # Intel GPU firmware
      # "mitigations=off"  # Uncomment for performance over security
    ];

    # Server tuning
    kernel.sysctl = {
      "fs.file-max" = 2097152;          # Higher file descriptor limit
      "net.core.rmem_max" = 134217728;  # Network buffer tuning
      "net.core.wmem_max" = 134217728;
    };
  };

  hardware = {
    # Intel graphics for compute workloads
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver    # Intel GPU driver
        libvdpau-va-gl
        intel-compute-runtime # OpenCL support
        level-zero            # Intel compute API
      ];
    };

    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = false;  # Power saving
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "powersave";
  };

  services = {
    thermald.enable = true;  # Intel thermal management

    # K3s Kubernetes cluster
    k3s = {
      enable = true;
      role = "server";  # This node is a control plane
      clusterInit = true;  # Initialize new cluster
      tokenFile = config.sops.secrets."k3s/token".path;
    };

    # Disable desktop services
    xserver.enable = false;
    printing.enable = false;
    pipewire.enable = false;
    avahi.enable = false;
    udisks2.enable = false;
    power-profiles-daemon.enable = false;
  };

  systemd = {
    # Automatically set up kubectl access for Ellen
    services.setup-ellen-kubeconfig = {
      description = "Setup kubectl access for Ellen";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${../common/scripts/setup-kubeconfig.sh}";
      };
    };

    # Bootstrap MetalLB load balancer
    services.bootstrap-metallb = {
      description = "Bootstrap MetalLB load balancer";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" "setup-ellen-kubeconfig.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${../common/scripts/bootstrap-metallb.sh}";
        Environment = [
          "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
          "PATH=${pkgs.kubectl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:/run/wrappers/bin"
        ];
        User = "root";
        Group = "root";
      };
    };

    # Bootstrap ArgoCD automatically
    services.bootstrap-argocd = {
      description = "Bootstrap ArgoCD GitOps controller";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" "setup-ellen-kubeconfig.service" "bootstrap-metallb.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${../common/scripts/bootstrap-argocd.sh}";
        Environment = [
          "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
          "PATH=${pkgs.kubectl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:/run/wrappers/bin"
        ];
        User = "root";
        Group = "root";
      };
    };

    # Bootstrap ingress configuration
    services.bootstrap-ingress = {
      description = "Bootstrap ingress and external access";
      wantedBy = [ "multi-user.target" ];
      after = [ "bootstrap-metallb.service" "bootstrap-argocd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${../common/scripts/bootstrap-ingress.sh}";
        Environment = [
          "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
          "PATH=${pkgs.kubectl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:/run/wrappers/bin"
        ];
        User = "root";
        Group = "root";
      };
    };

    # No sleep for servers
    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';

    # Faster timeouts
    extraConfig = ''
      DefaultTimeoutStopSec=30s
      DefaultTimeoutStartSec=30s
    '';
  };
}
# infrastructure/nixos/hosts/misato/default.nix
# Misato node configuration (Intel N150 Mini PC)

{ config, pkgs, lib, ... }:

{
  imports = [ ./disko.nix ];

  networking = {
    hostName = "misato";
    useDHCP = lib.mkDefault true;
    wireless.enable = false;
  };

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    kernelParams = [ "i915.enable_guc=2" ];
    kernel.sysctl = {
      "fs.file-max" = 2097152;
      "net.core.rmem_max" = 134217728;
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
      
      # Install core components automatically
      extraFlags = toString [
        "--disable=traefik"  # We'll use our own ingress setup
        "--disable=servicelb"  # We'll use MetalLB instead
      ];
      
      # Install ArgoCD and MetalLB via manifests
      manifests = {
        argocd = {
          source = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml";
            sha256 = lib.fakeSha256;
          };
        };
        metallb = {
          source = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml";
            sha256 = lib.fakeSha256;
          };
        };
        metallb-config = {
          content = ''
            apiVersion: metallb.io/v1beta1
            kind: IPAddressPool
            metadata:
              name: nerv-pool
              namespace: metallb-system
            spec:
              addresses:
              - 192.168.1.110-192.168.1.150
            ---
            apiVersion: metallb.io/v1beta1
            kind: L2Advertisement
            metadata:
              name: nerv-l2
              namespace: metallb-system
            spec:
              ipAddressPools:
              - nerv-pool
          '';
        };
      };
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

    # Bootstrap complete GitOps platform
    services.bootstrap-nerv-gitops = {
      description = "Bootstrap NERV GitOps Platform";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" "setup-ellen-kubeconfig.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${../common/scripts/bootstrap-gitops.sh}";
        Environment = [
          "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
          "PATH=${pkgs.kubectl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:/run/wrappers/bin"
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
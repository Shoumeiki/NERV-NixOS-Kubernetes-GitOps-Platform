# infrastructure/nixos/hosts/misato/default.nix
# Misato node configuration (Intel N150 Mini PC)

{ config, pkgs, lib, ... }:

{
  imports = [ ./disko.nix ];

  # Node identity and role
  networking = {
    hostName = "misato";
    useDHCP = lib.mkDefault true;
    wireless.enable = false;
  };

  # Node role configuration for scalable architecture
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

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ 
      "kvm-intel"
      # Storage modules for Longhorn
      "iscsi_tcp"          # iSCSI over TCP
      "nfs"                # NFS client support
      "nfsd"               # NFS server support (for RWX)
      "dm_crypt"           # Device mapper crypto
      "dm_mod"             # Device mapper
    ];
    extraModulePackages = [ ];
    kernelParams = [ "i915.enable_guc=2" ];
    kernel.sysctl = {
      "fs.file-max" = 2097152;
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
    };
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        libvdpau-va-gl
        intel-compute-runtime
        level-zero
      ];
    };
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = false;
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "powersave";
  };

  services = {
    thermald.enable = true;
    k3s = {
      enable = true;
      role = "server";
      clusterInit = true;
      tokenFile = config.sops.secrets."k3s/token".path;
      
      extraFlags = toString ([
        "--disable=traefik"
        "--disable=servicelb"
      ] ++ (lib.mapAttrsToList (key: value: "--node-label=${key}=${value}") config.nerv.nodeRole.nodeLabels));
    };

    nerv = {
      argocd = {
        enable = true;
        loadBalancerIP = config.nerv.network.services.argocd;
        repositoryUrl = config.nerv.network.repository.url;
      };
      
      metallb = {
        enable = true;
      };

      longhorn = {
        enable = true;
        singleNodeMode = true;  # Will scale to multi-node automatically
        ui.loadBalancerIP = config.nerv.network.services.longhorn;
      };
    };

    xserver.enable = false;
    printing.enable = false;
    pipewire.enable = false;
    avahi.enable = false;
    udisks2.enable = false;
    power-profiles-daemon.enable = false;
  };

  systemd = {
    services = {
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

      bootstrap-nerv-gitops = {
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
    };

    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';

    extraConfig = ''
      DefaultTimeoutStopSec=30s
      DefaultTimeoutStartSec=30s
    '';
  };
}
# modules/node-roles.nix
# Scalable node role definitions for mixed hardware layouts

{ config, lib, ... }:

with lib;

let
  cfg = config.nerv.nodeRole;
in

{
  options.nerv.nodeRole = {
    # Node role determines resource allocation and service placement
    role = mkOption {
      type = types.enum [ "control-plane" "storage" "compute" "worker" "edge" ];
      default = "control-plane";
      description = "Primary role of this node in the cluster";
    };

    # Hardware profile affects storage and compute configuration
    hardwareProfile = mkOption {
      type = types.enum [ "mini-pc" "server" "workstation" "vm" "raspberry-pi" ];
      default = "mini-pc";
      description = "Hardware profile for optimized configuration";
    };

    # Storage configuration per role
    storage = {
      dedicated = mkOption {
        type = types.bool;
        default = cfg.role == "storage";
        description = "Whether this node has dedicated storage disks";
      };

      allowScheduling = mkOption {
        type = types.bool;
        default = cfg.role != "compute";
        description = "Allow Longhorn to schedule storage on this node";
      };

      tier = mkOption {
        type = types.enum [ "fast" "standard" "backup" ];
        default = "standard";
        description = "Storage tier for Longhorn scheduling";
      };
    };

    # Compute configuration per role
    compute = {
      allowWorkloads = mkOption {
        type = types.bool;
        default = cfg.role != "storage";
        description = "Allow general workloads on this node";
      };

      maxPods = mkOption {
        type = types.int;
        default = 
          if cfg.role == "control-plane" then 50
          else if cfg.role == "storage" then 20
          else if cfg.role == "compute" then 200
          else 100;
        description = "Maximum pods per node";
      };
    };

    # Network configuration per role
    network = {
      loadBalancerEligible = mkOption {
        type = types.bool;
        default = cfg.role == "control-plane" || cfg.role == "worker";
        description = "Eligible for MetalLB load balancer services";
      };
    };

    # Internal options for node configuration
    nodeLabels = mkOption {
      type = types.attrs;
      internal = true;
      readOnly = true;
      description = "Kubernetes node labels for scheduling";
    };

    nodeTaints = mkOption {
      type = types.listOf types.attrs;
      internal = true;
      readOnly = true;
      description = "Kubernetes node taints for workload isolation";
    };
  };

  config = {
    # Export node labels for Kubernetes scheduling
    nerv.nodeRole.nodeLabels = {
      "nerv.io/role" = cfg.role;
      "nerv.io/hardware-profile" = cfg.hardwareProfile;
      "nerv.io/storage-tier" = cfg.storage.tier;
      "longhorn.io/create-default-disk" = 
        if cfg.storage.allowScheduling then "true" else "false";
    };

    # Export node taints for workload isolation
    nerv.nodeRole.nodeTaints = mkIf (cfg.role == "storage") [
      {
        key = "nerv.io/storage-only";
        value = "true";
        effect = "NoSchedule";
      }
    ];
  };
}
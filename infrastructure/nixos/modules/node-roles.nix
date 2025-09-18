# File: infrastructure/nixos/modules/node-roles.nix
# Description: Kubernetes node role configuration with workload scheduling and resource allocation
# Learning Focus: Complex NixOS options, conditional configurations, and Kubernetes node management

{ config, lib, ... }:

with lib;

let
  cfg = config.nerv.nodeRole;
in

{
  # Define node role options for different Kubernetes cluster configurations
  options.nerv.nodeRole = {
    role = mkOption {
      type = types.enum [ "control-plane" "storage" "compute" "worker" "edge" ];
      default = "control-plane";
      description = "Node role in cluster: control-plane, storage, compute, worker, or edge";
    };

    hardwareProfile = mkOption {
      type = types.enum [ "mini-pc" "server" "workstation" "vm" "raspberry-pi" ];
      default = "mini-pc";
      description = "Hardware profile for optimization: mini-pc, server, workstation, vm, or raspberry-pi";
    };

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

    network = {
      loadBalancerEligible = mkOption {
        type = types.bool;
        default = cfg.role == "control-plane" || cfg.role == "worker";
        description = "Eligible for MetalLB load balancer services";
      };
    };

    # Internal computed values for Kubernetes node configuration
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

  # Generate Kubernetes labels and taints based on node role configuration
  config = {
    nerv.nodeRole.nodeLabels = {
      "nerv.io/role" = cfg.role;
      "nerv.io/hardware-profile" = cfg.hardwareProfile;
      "nerv.io/storage-tier" = cfg.storage.tier;
      "node.longhorn.io/create-default-disk" =
        if cfg.storage.allowScheduling then "true" else "false";
    };

    nerv.nodeRole.nodeTaints = mkIf (cfg.role == "storage") [
      {
        key = "nerv.io/storage-only";
        value = "true";
        effect = "NoSchedule";
      }
    ];
  };
}
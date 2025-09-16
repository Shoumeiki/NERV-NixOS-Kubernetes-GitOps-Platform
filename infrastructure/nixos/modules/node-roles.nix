# modules/node-roles.nix
#
# Kubernetes Node Role Architecture - Enterprise Cluster Planning
#
# LEARNING OBJECTIVE: This module demonstrates enterprise Kubernetes node
# role management and workload scheduling patterns. Key learning areas:
#
# 1. NODE SPECIALIZATION: Role-based resource allocation and service placement
# 2. HARDWARE ABSTRACTION: Profile-based configuration for diverse hardware
# 3. WORKLOAD SCHEDULING: Kubernetes labels and taints for intelligent placement
# 4. STORAGE ORCHESTRATION: Longhorn integration with node-specific capabilities
#
# WHY NODE ROLE ARCHITECTURE MATTERS:
# - Different workloads have different resource requirements and constraints
# - Storage nodes require dedicated hardware resources and reliability
# - Control plane nodes need resource isolation for cluster stability
# - Efficient resource utilization requires workload-to-node matching
#
# ENTERPRISE PATTERN: This design enables cluster expansion with mixed
# hardware while maintaining performance predictability and operational
# efficiency through intelligent workload placement.

{ config, lib, ... }:

with lib;

let
  cfg = config.nerv.nodeRole;
in

{
  options.nerv.nodeRole = {
    # KUBERNETES NODE ROLE: Determines resource allocation and workload scheduling
    role = mkOption {
      type = types.enum [ "control-plane" "storage" "compute" "worker" "edge" ];
      default = "control-plane";
      description = ''
        Primary role of this node in the cluster architecture:
        - control-plane: Kubernetes API server, etcd, scheduler (limited workloads)
        - storage: Dedicated storage nodes with high-performance disks
        - compute: CPU-intensive workloads, machine learning, CI/CD runners
        - worker: General-purpose workload nodes for applications
        - edge: Resource-constrained edge computing locations
      '';
    };

    # HARDWARE PROFILE: Physical hardware optimization and capability detection
    hardwareProfile = mkOption {
      type = types.enum [ "mini-pc" "server" "workstation" "vm" "raspberry-pi" ];
      default = "mini-pc";
      description = ''
        Hardware profile for platform-specific optimizations:
        - mini-pc: Intel NUC, Beelink, other small form factor systems
        - server: Rack-mount servers with enterprise storage and networking
        - workstation: High-performance desktop systems with GPU acceleration
        - vm: Virtual machines with resource constraints and scheduling limitations
        - raspberry-pi: ARM-based edge devices with power and performance constraints
      '';
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
      "node.longhorn.io/create-default-disk" =
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
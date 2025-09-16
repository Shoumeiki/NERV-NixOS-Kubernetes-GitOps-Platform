# modules/services/longhorn.nix
# Longhorn distributed storage with scalable architecture

{ config, lib, ... }:

with lib;

let
  cfg = config.services.nerv.longhorn;
  networkCfg = config.nerv.network;
in

{
  options.services.nerv.longhorn = {
    enable = mkEnableOption "Longhorn distributed storage";

    namespace = mkOption {
      type = types.str;
      default = "longhorn-system";
      description = "Kubernetes namespace for Longhorn";
    };

    # Single-node development vs multi-node production
    singleNodeMode = mkOption {
      type = types.bool;
      default = true;
      description = "Configure for single-node development (replica count = 1)";
    };

    defaultReplicaCount = mkOption {
      type = types.int;
      default = if cfg.singleNodeMode then 1 else 3;
      description = "Default replica count for volumes";
    };

    # Storage configuration
    defaultStorageClass = {
      reclaimPolicy = mkOption {
        type = types.str;
        default = "Retain";
        description = "Default reclaim policy for volumes";
      };

      allowVolumeExpansion = mkOption {
        type = types.bool;
        default = true;
        description = "Allow volume expansion";
      };
    };

    # UI and monitoring
    ui = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Longhorn UI";
      };

      loadBalancerIP = mkOption {
        type = types.str;
        default = "192.168.1.111";
        description = "LoadBalancer IP for Longhorn UI";
      };
    };

    # Node and disk configuration
    nodeConfiguration = {
      # Allow scheduling on master node for single-node setups
      allowSchedulingOnMaster = mkOption {
        type = types.bool;
        default = cfg.singleNodeMode;
        description = "Allow scheduling on master nodes";
      };

      # Storage allocation
      storageOverProvisioningPercentage = mkOption {
        type = types.int;
        default = if cfg.singleNodeMode then 200 else 100;
        description = "Storage over-provisioning percentage";
      };

      storageMinimalAvailablePercentage = mkOption {
        type = types.int;
        default = 25;
        description = "Minimal available storage percentage";
      };
    };
  };

  config = mkIf cfg.enable {
    # Note: Longhorn will be deployed via ArgoCD using Helm charts
    # This module provides configuration values for the deployment
  };
}
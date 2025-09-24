# File: infrastructure/nixos/modules/node-roles.nix
# Description: Simplified Kubernetes node role configuration
# Learning Focus: Clean NixOS options with room for multi-node growth

{ config, lib, ... }:

with lib;

let
  cfg = config.nerv.nodeRole;
in

{
  options.nerv.nodeRole = {
    role = mkOption {
      type = types.enum [ "control-plane" "worker" ];
      default = "control-plane";
      description = "Node role: control-plane (runs workloads) or worker (workloads only)";
    };

    nodeLabels = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "Kubernetes node labels for scheduling";
    };

    nodeTaints = mkOption {
      type = types.listOf types.attrs;
      readOnly = true;
      description = "Kubernetes node taints for workload isolation";
    };
  };

  config = {
    nerv.nodeRole.nodeLabels = {
      "nerv.io/role" = cfg.role;
      "node.longhorn.io/create-default-disk" = "true";
    };

    nerv.nodeRole.nodeTaints = [ ];
  };
}
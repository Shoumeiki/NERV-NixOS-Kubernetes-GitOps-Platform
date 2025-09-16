# modules/network.nix
# Centralized network configuration for NERV platform

{ config, lib, ... }:

with lib;

let
  cfg = config.nerv.network;
in

{
  options.nerv.network = {
    # MetalLB IP pool configuration
    loadBalancerPool = {
      start = mkOption {
        type = types.str;
        default = "192.168.1.110";
        description = "Starting IP address for MetalLB pool";
      };

      end = mkOption {
        type = types.str;
        default = "192.168.1.150";
        description = "Ending IP address for MetalLB pool";
      };

      name = mkOption {
        type = types.str;
        default = "nerv-pool";
        description = "MetalLB IP address pool name";
      };
    };

    # Service-specific IP assignments
    services = {
      argocd = mkOption {
        type = types.str;
        default = "192.168.1.110";
        description = "Static IP for ArgoCD LoadBalancer service";
      };

      longhorn = mkOption {
        type = types.str;
        default = "192.168.1.111";
        description = "Static IP for Longhorn UI LoadBalancer service";
      };

      # Future service IPs
      # monitoring = mkOption {
      #   type = types.str;
      #   default = "192.168.1.112";
      #   description = "Static IP for monitoring stack";
      # };
    };

    # Repository configuration
    repository = {
      url = mkOption {
        type = types.str;
        default = "https://github.com/Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git";
        description = "Git repository URL for GitOps workflows";
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        description = "Git branch for GitOps synchronization";
      };
    };
  };
}
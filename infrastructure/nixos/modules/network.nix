# File: infrastructure/nixos/modules/network.nix
# Description: Centralized network configuration for MetalLB and GitOps repository settings
# Learning Focus: NixOS module system, network service IP allocation, and GitOps integration

{ config, lib, ... }:

with lib;

let
  cfg = config.nerv.network;
in

{
  # Define configuration options for network services and GitOps deployment
  options.nerv.network = {
    loadBalancerPool = {
      start = mkOption {
        type = types.str;
        default = "192.168.1.111";
        description = "Starting IP address for MetalLB load balancer pool";
      };

      end = mkOption {
        type = types.str;
        default = "192.168.1.150";
        description = "Ending IP address for MetalLB load balancer pool";
      };

      name = mkOption {
        type = types.str;
        default = "nerv-pool";
        description = "MetalLB IP address pool name";
      };
    };

    services = {
      dns = mkOption {
        type = types.str;
        default = "192.168.1.111";
        description = "Static IP for DNS service LoadBalancer";
      };

      traefik = mkOption {
        type = types.str;
        default = "192.168.1.112";
        description = "Static IP for Traefik ingress controller LoadBalancer";
      };

      longhorn = mkOption {
        type = types.str;
        default = "192.168.1.113";
        description = "Static IP for Longhorn storage management UI LoadBalancer";
      };

      monitoring = mkOption {
        type = types.str;
        default = "192.168.1.114";
        description = "Static IP for monitoring services LoadBalancer";
      };
    };

    repository = {
      url = mkOption {
        type = types.str;
        default = "https://github.com/Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git";
        description = "Git repository URL for GitOps deployment";
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        description = "Git branch for GitOps deployment";
      };
    };
  };
}
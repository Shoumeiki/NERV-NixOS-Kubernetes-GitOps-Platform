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

    # Reserved for future service static IP assignments if needed
    # Currently using dynamic MetalLB allocation for simplicity
  };
}
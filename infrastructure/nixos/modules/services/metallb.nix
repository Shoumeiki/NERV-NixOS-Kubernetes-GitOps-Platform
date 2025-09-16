# modules/services/metallb.nix  
# MetalLB load balancer for bare metal Kubernetes

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.metallb;
  networkCfg = config.nerv.network;
in

{
  options.services.nerv.metallb = {
    enable = mkEnableOption "MetalLB load balancer";

    namespace = mkOption {
      type = types.str;
      default = "metallb-system";
      description = "Kubernetes namespace for MetalLB";
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # MetalLB core installation
      metallb = {
        source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml";
          sha256 = "sha256-EbWQYCH95WBAzxDRvLr1wrekIGBF67EDkVNH38xTPw4=";
        };
      };

      # MetalLB IP address pool configuration
      metallb-config = {
        content = [
          {
            apiVersion = "metallb.io/v1beta1";
            kind = "IPAddressPool";
            metadata = {
              name = networkCfg.loadBalancerPool.name;
              namespace = cfg.namespace;
            };
            spec = {
              addresses = [ networkCfg.calculatedValues.metallbAddressRange ];
            };
          }
          {
            apiVersion = "metallb.io/v1beta1";
            kind = "L2Advertisement";
            metadata = {
              name = "${networkCfg.loadBalancerPool.name}-l2";
              namespace = cfg.namespace;
            };
            spec = {
              ipAddressPools = [ networkCfg.loadBalancerPool.name ];
            };
          }
        ];
      };
    };
  };
}
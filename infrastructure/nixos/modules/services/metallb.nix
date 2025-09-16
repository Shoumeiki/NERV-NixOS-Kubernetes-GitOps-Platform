# modules/services/metallb.nix
#
# MetalLB Load Balancer - Cloud Load Balancer for Bare Metal Kubernetes
#
# LEARNING OBJECTIVE: This module demonstrates how to provide LoadBalancer
# services in bare metal Kubernetes environments. Key learning areas:
#
# 1. BARE METAL NETWORKING: Replacing cloud provider load balancers
# 2. IP ADDRESS MANAGEMENT: Static IP pool allocation and advertisement
# 3. LAYER 2 NETWORKING: ARP-based IP advertisement for local networks
# 4. SERVICE INTEGRATION: Enabling standard LoadBalancer service types
#
# WHY METALLB IS ESSENTIAL FOR BARE METAL:
# - Cloud providers automatically provision LoadBalancers (AWS ELB, GCP LB)
# - Bare metal clusters lack this capability by default
# - Applications expect LoadBalancer services for external access
# - MetalLB bridges this gap by managing IP allocation and advertisement
#
# L2 MODE OPERATION: This configuration uses Layer 2 mode, where MetalLB
# announces LoadBalancer IPs via ARP, making services accessible on the
# local network without requiring BGP or routing protocol configuration.

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
      description = ''
        Dedicated namespace for MetalLB load balancer components. Follows
        Kubernetes best practice of isolating infrastructure services.
        Standard namespace name used across MetalLB documentation.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # DEPLOYMENT STRATEGY: Official upstream manifests for stability
      # MetalLB native manifests provide the complete controller and speaker
      # DaemonSet without Helm complexity or version compatibility issues
      metallb = {
        source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml";
          sha256 = "sha256-obBMN2+znJMmX1Uf4jcWo65uCbeQ7bO/JX0/x4TDWhg=";
        };
      };

      # NETWORK CONFIGURATION: IP pool and advertisement strategy
      # Defines which IP addresses MetalLB can assign to LoadBalancer services
      # and how those IPs are announced to the network infrastructure
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
              addresses = [ "${networkCfg.loadBalancerPool.start}-${networkCfg.loadBalancerPool.end}" ];
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
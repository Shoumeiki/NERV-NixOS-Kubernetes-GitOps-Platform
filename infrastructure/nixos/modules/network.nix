# modules/network.nix
#
# Centralized Network Configuration - NERV Platform Network Architecture
#
# LEARNING OBJECTIVE: This module demonstrates enterprise network planning and
# IP address management (IPAM) for Kubernetes platforms. Key learning areas:
#
# 1. STATIC IP ALLOCATION: Predictable service access through fixed IP assignments
# 2. LOAD BALANCER POOLS: MetalLB IP range management for bare metal clusters
# 3. SERVICE DISCOVERY: Consistent network endpoints for platform services
# 4. GITOPS INTEGRATION: Repository configuration for declarative infrastructure
#
# WHY CENTRALIZED NETWORK CONFIGURATION MATTERS:
# - Prevents IP conflicts through systematic allocation
# - Enables predictable DNS records and firewall rules
# - Simplifies network troubleshooting and documentation
# - Facilitates disaster recovery and infrastructure migration
#
# ENTERPRISE NETWORK DESIGN: This configuration establishes a foundation for
# multi-node cluster expansion while maintaining service continuity and
# operational predictability.

{ config, lib, ... }:

with lib;

let
  cfg = config.nerv.network;
in

{
  options.nerv.network = {
    # METALLB LOAD BALANCER POOL: IP range allocation for Kubernetes LoadBalancer services
    # This pool provides external IP addresses for services requiring external access
    loadBalancerPool = {
      start = mkOption {
        type = types.str;
        default = "192.168.1.110";
        description = ''
          Starting IP address for MetalLB load balancer pool. This should be
          within your local network range but outside DHCP allocation to
          prevent conflicts. Reserved for platform infrastructure services.
        '';
      };

      end = mkOption {
        type = types.str;
        default = "192.168.1.150";
        description = ''
          Ending IP address for MetalLB pool, providing 41 available IPs
          (110-150) for LoadBalancer services. Sufficient for platform
          services plus future application deployments.
        '';
      };

      name = mkOption {
        type = types.str;
        default = "nerv-pool";
        description = ''
          MetalLB IP address pool name for Kubernetes resource identification.
          Used in IPAddressPool and L2Advertisement resource configurations.
        '';
      };
    };

    # PLATFORM SERVICE IP ALLOCATION: Fixed IP addresses for core infrastructure services
    # Static IPs enable predictable DNS records, firewall rules, and external access
    services = {
      argocd = mkOption {
        type = types.str;
        default = "192.168.1.110";
        description = ''
          Static IP for ArgoCD GitOps dashboard LoadBalancer service.
          Primary interface for GitOps management and application deployment
          monitoring. Requires external access for development workflow.
        '';
      };

      longhorn = mkOption {
        type = types.str;
        default = "192.168.1.111";
        description = ''
          Static IP for Longhorn storage management UI LoadBalancer service.
          Provides web interface for volume management, backup configuration,
          and storage performance monitoring. Administrative access only.
        '';
      };

      traefik = mkOption {
        type = types.str;
        default = "192.168.1.112";
        description = ''
          Static IP for Traefik ingress controller LoadBalancer service.
          Primary entry point for all HTTP/HTTPS traffic to the cluster.
          Handles SSL termination and routing to backend services.
        '';
      };

      # FUTURE SERVICE RESERVATIONS: Pre-planned IP allocation for expansion
      # monitoring = mkOption {
      #   type = types.str;
      #   default = "192.168.1.113";
      #   description = "Static IP for Prometheus/Grafana monitoring stack";
      # };

      # dns = mkOption {
      #   type = types.str;
      #   default = "192.168.1.114";
      #   description = "Static IP for Pi-hole or AdGuard DNS service";
      # };
    };

    # GITOPS REPOSITORY CONFIGURATION: Source of truth for infrastructure and applications
    repository = {
      url = mkOption {
        type = types.str;
        default = "https://github.com/Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git";
        description = ''
          Git repository URL serving as the single source of truth for GitOps
          workflows. ArgoCD monitors this repository for changes and automatically
          synchronizes cluster state. HTTPS URL used for public repository access.
        '';
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        description = ''
          Git branch for GitOps synchronization and deployment automation.
          All changes to this branch trigger automatic deployment via ArgoCD.
          Production environments should use protected branches with PR workflows.
        '';
      };
    };
  };
}
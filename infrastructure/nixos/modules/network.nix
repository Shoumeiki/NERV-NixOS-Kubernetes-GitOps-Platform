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
        default = "192.168.1.111";
        description = ''
          Starting IP address for MetalLB load balancer pool.

          IP Allocation Strategy:
          - 192.168.1.100-110: Reserved for Kubernetes nodes
          - 192.168.1.111-120: Reserved for core platform services
          - 192.168.1.121-150: Dynamic allocation for applications
        '';
      };

      end = mkOption {
        type = types.str;
        default = "192.168.1.150";
        description = ''
          Ending IP address for MetalLB pool, providing 40 available IPs
          (111-150) for LoadBalancer services. This range supports both
          reserved core services and dynamic application allocation.
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
      dns = mkOption {
        type = types.str;
        default = "192.168.1.111";
        description = ''
          Static IP for DNS service (Pi-hole or CoreDNS) LoadBalancer service.
          Provides network-wide DNS resolution, ad-blocking, and custom domain
          management. Critical infrastructure service requiring predictable IP.
        '';
      };

      traefik = mkOption {
        type = types.str;
        default = "192.168.1.112";
        description = ''
          Static IP for Traefik ingress controller and dashboard LoadBalancer.
          Primary entry point for HTTP/HTTPS traffic with web UI for routing
          management, middleware configuration, and certificate monitoring.
        '';
      };

      longhorn = mkOption {
        type = types.str;
        default = "192.168.1.113";
        description = ''
          Static IP for Longhorn distributed storage management UI.
          Provides web interface for volume management, backup configuration,
          and storage performance monitoring. Administrative access only.
        '';
      };

      # Reserved for future core services (192.168.1.114-120)
      monitoring = mkOption {
        type = types.str;
        default = "192.168.1.114";
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
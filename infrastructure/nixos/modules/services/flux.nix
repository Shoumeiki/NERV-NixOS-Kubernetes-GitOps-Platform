# infrastructure/nixos/modules/services/flux.nix
#
# NERV Flux v2 GitOps Controller
#
# LEARNING OBJECTIVE: This module demonstrates enterprise-grade GitOps implementation
# using Flux v2 as the foundation for self-service platform engineering. Key learning areas:
#
# 1. GITOPS FOUNDATION: Flux v2 controllers for declarative cluster management
# 2. BOOTSTRAP AUTOMATION: Complete GitOps setup from NixOS deployment
# 3. REPOSITORY INTEGRATION: Seamless Git repository sync and reconciliation
# 4. HELM INTEGRATION: Native Helm chart management through GitOps workflows
#
# WHY FLUX V2 FOR PLATFORM ENGINEERING:
# - Native Kubernetes controllers built on controller-runtime
# - Proven scalability (200+ clusters with 10 engineers at major companies)
# - Self-service platform enablement for development teams
# - Built-in security with RBAC, SOPS, and multi-tenancy support
#
# ENTERPRISE PATTERN: Platform teams create GitOps foundations that enable
# development teams to deploy applications confidently through Git workflows,
# reducing operational overhead while maintaining security and compliance.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nerv.flux;
in

{
  options.nerv.flux = {
    # Core Flux enablement for GitOps workflows
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable Flux v2 GitOps controllers for declarative cluster management.

        Flux v2 provides the foundation for platform engineering by enabling:
        - Git as single source of truth for cluster state
        - Automatic reconciliation and drift detection
        - Native Helm chart management with HelmRelease CRDs
        - Multi-tenancy and progressive deployment capabilities

        Essential for teams building self-service Kubernetes platforms.
      '';
    };

    # GitOps repository configuration - central source of truth
    repository = {
      url = mkOption {
        type = types.str;
        description = ''
          Git repository URL containing Kubernetes manifests and Helm releases.

          This repository becomes the single source of truth for cluster state.
          All infrastructure changes flow through Git workflows, providing:
          - Audit trail for all cluster modifications
          - Rollback capabilities through Git history
          - Collaborative review process via pull requests
          - Compliance through version-controlled infrastructure
        '';
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        description = ''
          Git branch for Flux to monitor and sync from.

          Recommended patterns:
          - 'main': Single environment (development/demo)
          - 'staging'/'production': Multi-environment with branch-based promotion
          - Feature branches for testing infrastructure changes
        '';
      };

      path = mkOption {
        type = types.str;
        default = "infrastructure/kubernetes";
        description = ''
          Directory path within repository containing Kubernetes manifests.

          Recommended structure:
          - infrastructure/kubernetes/flux-system/ (Flux configuration)
          - infrastructure/kubernetes/sources/ (GitRepository, HelmRepository)
          - infrastructure/kubernetes/releases/ (HelmReleases for services)
        '';
      };
    };

    # Namespace strategy for security isolation
    namespace = mkOption {
      type = types.str;
      default = "flux-system";
      description = ''
        Dedicated namespace for Flux controllers following enterprise security
        principle of isolation. Benefits include:
        - Specific security policies and RBAC
        - Resource quotas and limits
        - Audit and compliance reporting
        - Clear separation from application workloads
      '';
    };

    # GitOps reconciliation timing
    interval = mkOption {
      type = types.str;
      default = "1m";
      description = ''
        Reconciliation interval for Git repository polling.

        Recommended values:
        - '30s': Development (fast feedback)
        - '1m': Production (balanced)
        - '5m': Large scale (reduced API load)

        Flux also supports webhook-driven reconciliation for immediate updates.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Flux v2 namespace with proper labels and security policies
    services.k3s.manifests = {
      flux-namespace = {
        content = {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "flux-system";
              "app.kubernetes.io/component" = "gitops";
              "app.kubernetes.io/part-of" = "flux";
              # Security policies for Flux controllers
              "pod-security.kubernetes.io/enforce" = "restricted";
              "pod-security.kubernetes.io/audit" = "restricted";
              "pod-security.kubernetes.io/warn" = "restricted";
            };
          };
        };
      };

      # Install Flux v2 controllers using official manifests
      # STABILITY FOCUS: Using stable release for production-ready deployment
      flux-system-install = {
        source = pkgs.fetchurl {
          url = "https://github.com/fluxcd/flux2/releases/download/v2.4.0/install.yaml";
          sha256 = "sha256-yGqnc8nwX7LhPTa7I7oPL8HaZG8kKRbxOwX6pRPbLOU=";
        };
      };

      # GitRepository CRD - defines the source Git repository
      flux-git-repository = {
        content = {
          apiVersion = "source.toolkit.fluxcd.io/v1";
          kind = "GitRepository";
          metadata = {
            name = "nerv-platform";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "nerv-platform";
              "app.kubernetes.io/component" = "source";
            };
          };
          spec = {
            interval = cfg.interval;
            url = cfg.repository.url;
            ref = {
              branch = cfg.repository.branch;
            };
            # Security: Verify Git signatures in production
            # verify = {
            #   mode = "strict";
            #   secretRef = {
            #     name = "flux-git-signing-key";
            #   };
            # };
          };
        };
      };

      # Kustomization CRD - applies manifests from Git repository
      flux-kustomization = {
        content = {
          apiVersion = "kustomize.toolkit.fluxcd.io/v1";
          kind = "Kustomization";
          metadata = {
            name = "nerv-infrastructure";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "nerv-infrastructure";
              "app.kubernetes.io/component" = "kustomization";
            };
          };
          spec = {
            interval = cfg.interval;
            sourceRef = {
              kind = "GitRepository";
              name = "nerv-platform";
            };
            path = cfg.repository.path;
            prune = true;  # Remove resources not in Git
            wait = true;   # Wait for resources to be ready
            timeout = "5m";
            # Health checks for deployed resources
            healthChecks = [
              {
                apiVersion = "apps/v1";
                kind = "Deployment";
                name = ".*";
                namespace = ".*";
              }
              {
                apiVersion = "v1";
                kind = "Service";
                name = ".*";
                namespace = ".*";
              }
            ];
            # Force apply for CRDs and other cluster-wide resources
            force = true;
          };
        };
      };

      # Flux alerts for operational visibility (future enhancement)
      flux-alerts = {
        content = {
          apiVersion = "notification.toolkit.fluxcd.io/v1beta1";
          kind = "Alert";
          metadata = {
            name = "nerv-platform-alerts";
            namespace = cfg.namespace;
          };
          spec = {
            providerRef = {
              name = "generic-webhook";  # Configure webhook endpoint
            };
            eventSeverity = "info";
            eventSources = [
              {
                kind = "GitRepository";
                name = "nerv-platform";
              }
              {
                kind = "Kustomization";
                name = "nerv-infrastructure";
              }
            ];
            summary = "NERV Platform GitOps Events";
          };
        };
      };
    };

    # System integration: ensure Flux starts after K3s
    systemd.services.flux-bootstrap = {
      description = "Bootstrap Flux GitOps for NERV Platform";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      wants = [ "k3s.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "flux-bootstrap" ''
          set -euo pipefail

          echo "NERV Flux Bootstrap - Initializing GitOps..."

          # Wait for K3s to be ready
          echo "Waiting for Kubernetes API..."
          timeout=60
          while ! ${pkgs.kubectl}/bin/kubectl get nodes >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
            sleep 2
            ((timeout--))
          done

          if [[ $timeout -eq 0 ]]; then
            echo "Kubernetes API not available after 120 seconds"
            exit 1
          fi

          echo "Kubernetes API ready"
          echo "Flux controllers will automatically sync from Git repository"
          echo "   Repository: ${cfg.repository.url}"
          echo "   Branch: ${cfg.repository.branch}"
          echo "   Path: ${cfg.repository.path}"
          echo ""
          echo "GitOps foundation ready for NERV platform management"
        ''}";

        # Security: run as dedicated user
        User = "nobody";
        Group = "nogroup";
      };
    };
  };
}
# File: infrastructure/nixos/modules/services/flux.nix
# Description: Flux v2 GitOps controller configuration
# Learning Focus: Declarative GitOps with Kubernetes CRDs

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nerv.flux;
in

{
  options.nerv.flux = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Flux v2 GitOps controllers";
    };

    repository = {
      url = mkOption {
        type = types.str;
        description = "Git repository URL for GitOps";
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        description = "Git branch to monitor";
      };

      path = mkOption {
        type = types.str;
        default = "infrastructure/kubernetes";
        description = "Path within repository";
      };
    };

    namespace = mkOption {
      type = types.str;
      default = "flux-system";
      description = "Flux namespace";
    };

    interval = mkOption {
      type = types.str;
      default = "1m";
      description = "Reconciliation interval";
    };

    # Performance optimization options for Flux v2.6
    optimization = {
      retryInterval = mkOption {
        type = types.str;
        default = "2m";
        description = "Retry interval for failed reconciliations";
      };

      timeout = mkOption {
        type = types.str;
        default = "10m";
        description = "Timeout for reconciliation operations";
      };

      suspend = mkOption {
        type = types.bool;
        default = false;
        description = "Suspend reconciliation for maintenance";
      };
    };
  };

  config = mkIf cfg.enable {
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
              # Flux controllers can run with restricted security
              "pod-security.kubernetes.io/enforce" = "restricted";
              "pod-security.kubernetes.io/audit" = "restricted";
              "pod-security.kubernetes.io/warn" = "restricted";
            };
          };
        };
      };

      flux-system-install = {
        source = pkgs.fetchurl {
          url = "https://github.com/fluxcd/flux2/releases/download/v2.6.1/install.yaml";
          sha256 = "sha256-1e9lSJ+aaDcq1iadq3nW7+m4opHz+j6rlcu1V10wP/Y=";
        };
      };

      flux-git-repository = {
        content = {
          apiVersion = "source.toolkit.fluxcd.io/v1";
          kind = "GitRepository";
          metadata = {
            name = "nerv-platform";
            namespace = cfg.namespace;
          };
          spec = {
            interval = cfg.interval;
            url = cfg.repository.url;
            ref.branch = cfg.repository.branch;
            # Performance optimization for large repositories
            gitImplementation = "go-git";
            # Reduce clone depth for faster syncs
            gitSpec = {
              depth = 1;
            };
          };
        };
      };

      flux-kustomization = {
        content = {
          apiVersion = "kustomize.toolkit.fluxcd.io/v1";
          kind = "Kustomization";
          metadata = {
            name = "nerv-infrastructure";
            namespace = cfg.namespace;
          };
          spec = {
            interval = cfg.interval;
            retryInterval = cfg.optimization.retryInterval;
            timeout = cfg.optimization.timeout;
            suspend = cfg.optimization.suspend;
            sourceRef = {
              kind = "GitRepository";
              name = "nerv-platform";
            };
            path = cfg.repository.path;
            prune = true;
            wait = true;
            force = true;
            # Performance optimizations for Flux v2.6
            commonMetadata = {
              labels = {
                "app.kubernetes.io/managed-by" = "flux";
                "app.kubernetes.io/part-of" = "nerv-platform";
              };
            };
          };
        };
      };
    };

    # Simple health check service - Flux bootstrap handled via manifests
    systemd.services.flux-ready = {
      description = "Wait for Flux GitOps readiness";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      wants = [ "k3s.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "flux-ready" ''
          set -euo pipefail
          
          echo "Waiting for Kubernetes API..."
          timeout=60
          while ! ${pkgs.kubectl}/bin/kubectl get nodes >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
            sleep 2
            ((timeout--))
          done
          
          [[ $timeout -gt 0 ]] || { echo "Kubernetes API timeout"; exit 1; }
          echo "Kubernetes API ready - Flux will bootstrap via manifests"
        ''}";
        User = "nobody";
        Group = "nogroup";
      };
    };
  };
}
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
              "pod-security.kubernetes.io/enforce" = "restricted";
            };
          };
        };
      };

      flux-system-install = {
        source = pkgs.fetchurl {
          url = "https://github.com/fluxcd/flux2/releases/download/v2.4.0/install.yaml";
          sha256 = "sha256-OsoN5gSTLfljLGzI51Ioc9Fs3WIdHevPkSk1iabUGv4=";
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
            sourceRef = {
              kind = "GitRepository";
              name = "nerv-platform";
            };
            path = cfg.repository.path;
            prune = true;
            wait = true;
            timeout = "5m";
            force = true;
          };
        };
      };
    };

    systemd.services.flux-bootstrap = {
      description = "Bootstrap Flux GitOps";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      wants = [ "k3s.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "flux-bootstrap" ''
          set -euo pipefail
          
          timeout=60
          while ! ${pkgs.kubectl}/bin/kubectl get nodes >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
            sleep 2
            ((timeout--))
          done

          if [[ $timeout -eq 0 ]]; then
            echo "Kubernetes API not available"
            exit 1
          fi

          echo "Flux GitOps ready"
        ''}";
        User = "nobody";
        Group = "nogroup";
      };
    };
  };
}
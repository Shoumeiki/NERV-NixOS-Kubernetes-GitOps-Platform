# File: infrastructure/nixos/modules/services/flux.nix
# Description: Automated Flux v2 bootstrap via flux CLI
# Learning Focus: Flux bootstrap automation with GitHub integration

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

    github = {
      owner = mkOption {
        type = types.str;
        description = "GitHub repository owner/organization";
      };

      repository = mkOption {
        type = types.str;
        description = "GitHub repository name";
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        description = "Git branch to monitor";
      };

      path = mkOption {
        type = types.str;
        default = "infrastructure/kubernetes/flux-system";
        description = "Path within repository for Flux system manifests";
      };
    };

    namespace = mkOption {
      type = types.str;
      default = "flux-system";
      description = "Flux installation namespace";
    };

    interval = mkOption {
      type = types.str;
      default = "1m";
      description = "Reconciliation interval";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.fluxcd ];

    systemd.services.flux-bootstrap = {
      description = "Bootstrap Flux v2 GitOps";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" "network-online.target" ];
      wants = [ "k3s.service" "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [
          "KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
        ];
      };

      script = ''
        set -euo pipefail

        echo "Waiting for Kubernetes API..."
        timeout=60
        while ! ${pkgs.kubectl}/bin/kubectl get nodes >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
          sleep 2
          ((timeout--))
        done

        if [[ $timeout -eq 0 ]]; then
          echo "ERROR: Kubernetes API timeout"
          exit 1
        fi

        echo "Kubernetes API ready"

        # Check if Flux is already bootstrapped
        if ${pkgs.kubectl}/bin/kubectl get namespace ${cfg.namespace} >/dev/null 2>&1; then
          echo "Flux namespace already exists, checking deployment..."
          if ${pkgs.kubectl}/bin/kubectl get deployment -n ${cfg.namespace} source-controller >/dev/null 2>&1; then
            echo "Flux already bootstrapped, skipping"
            exit 0
          fi
        fi

        echo "Bootstrapping Flux v2..."
        export GITHUB_TOKEN=$(cat ${config.sops.secrets."github/flux-token".path})

        ${pkgs.fluxcd}/bin/flux bootstrap github \
          --owner=${cfg.github.owner} \
          --repository=${cfg.github.repository} \
          --branch=${cfg.github.branch} \
          --path=${cfg.github.path} \
          --personal \
          --interval=${cfg.interval}

        echo "Flux bootstrap complete"
      '';
    };
  };
}
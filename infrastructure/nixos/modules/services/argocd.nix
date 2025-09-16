# modules/services/argocd.nix
# ArgoCD GitOps deployment service with MetalLB integration

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.argocd;
in

{
  options.services.nerv.argocd = {
    enable = mkEnableOption "ArgoCD GitOps service";

    loadBalancerIP = mkOption {
      type = types.str;
      default = "192.168.1.110";
      description = "LoadBalancer IP address for ArgoCD service";
    };

    repositoryUrl = mkOption {
      type = types.str;
      description = "Git repository URL for GitOps configuration";
    };

    namespace = mkOption {
      type = types.str;
      default = "default";
      description = "Kubernetes namespace for ArgoCD deployment";
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # ArgoCD core installation
      argocd = {
        source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml";
          sha256 = "sha256-IQ5P36aTTbzCGhWX1uUA3r4pdlE7dlF/3TH4344LlsQ=";
        };
      };

      # ArgoCD LoadBalancer service for external access
      argocd-loadbalancer = {
        content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "argocd-server-lb";
            namespace = cfg.namespace;
            annotations = {
              "metallb.universe.tf/loadBalancerIPs" = cfg.loadBalancerIP;
            };
          };
          spec = {
            type = "LoadBalancer";
            ports = [
              {
                name = "server";
                port = 80;
                targetPort = 8080;
                protocol = "TCP";
              }
              {
                name = "grpc";
                port = 443;
                targetPort = 8080;
                protocol = "TCP";
              }
            ];
            selector = {
              "app.kubernetes.io/name" = "argocd-server";
            };
          };
        };
      };

      # Configure ArgoCD server for insecure mode (suitable for internal networks)
      argocd-server-insecure = {
        content = {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "argocd-server";
            namespace = cfg.namespace;
          };
          spec = {
            template = {
              spec = {
                containers = [
                  {
                    name = "argocd-server";
                    args = [
                      "argocd-server"
                      "--insecure"
                    ];
                  }
                ];
              };
            };
          };
        };
      };

      # Cluster-admin RBAC for ArgoCD application controller
      argocd-rbac-controller = {
        content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRoleBinding";
          metadata = {
            name = "argocd-application-controller-admin";
          };
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "cluster-admin";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "argocd-application-controller";
              namespace = cfg.namespace;
            }
          ];
        };
      };

      # Cluster-admin RBAC for ArgoCD server
      argocd-rbac-server = {
        content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRoleBinding";
          metadata = {
            name = "argocd-server-admin";
          };
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "cluster-admin";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "argocd-server";
              namespace = cfg.namespace;
            }
          ];
        };
      };

      # Git repository configuration for GitOps
      argocd-repository = {
        content = {
          apiVersion = "v1";
          kind = "Secret";
          metadata = {
            name = "nerv-repository";
            namespace = cfg.namespace;
            labels = {
              "argocd.argoproj.io/secret-type" = "repository";
            };
          };
          type = "Opaque";
          stringData = {
            type = "git";
            url = cfg.repositoryUrl;
          };
        };
      };
    };
  };
}
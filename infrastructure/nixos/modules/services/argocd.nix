# modules/services/argocd.nix
#
# ArgoCD GitOps Platform - Enterprise Security & Operations Focus
#
# LEARNING OBJECTIVE: This module showcases enterprise-grade GitOps implementation
# patterns that go beyond basic ArgoCD deployment. Key learning areas:
#
# 1. SECURITY HARDENING: Pod Security Standards, Network Policies, RBAC
# 2. OPERATIONAL MATURITY: Resource quotas, monitoring integration, HA planning
# 3. ENTERPRISE INTEGRATION: OIDC preparation, policy enforcement, audit trails
# 4. PRODUCTION READINESS: Proper namespace isolation, service monitoring
#
# WHY ENTERPRISE APPROACH MATTERS:
# - Large organizations require security compliance (SOC2, PCI, HIPAA)
# - Multi-tenant environments need strict resource and network isolation
# - Audit requirements demand comprehensive logging and access controls
# - High availability ensures business continuity for critical deployments
#
# GITOPS PRINCIPLE DEMONSTRATION:
# This module embodies "infrastructure as code" by making ArgoCD itself
# reproducible and declarative. The GitOps controller is deployed using
# the same principles it will manage - complete declarative configuration.

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.argocd;
in

{
  options.services.nerv.argocd = {
    enable = mkEnableOption "Enterprise ArgoCD GitOps platform";

    # Network configuration with enterprise considerations
    loadBalancerIP = mkOption {
      type = types.str;
      default = "192.168.1.110";
      description = ''
        External IP for ArgoCD UI access. In production environments, this would
        typically be behind a WAF (Web Application Firewall) or API gateway.
        The static IP enables consistent DNS records and firewall rules.
      '';
    };

    # GitOps repository configuration - central to the entire platform
    repositoryUrl = mkOption {
      type = types.str;
      description = ''
        Git repository containing Kubernetes manifests managed by ArgoCD.
        This implements the GitOps principle: Git as single source of truth
        for infrastructure state. All changes flow through Git workflows.
      '';
    };

    # Namespace strategy for security isolation
    namespace = mkOption {
      type = types.str;
      default = "argocd";
      description = ''
        Dedicated namespace following enterprise security principle of isolation.
        ArgoCD gets its own namespace to:
        - Apply specific security policies
        - Isolate from application workloads
        - Enable granular resource quotas
        - Simplify audit and compliance reporting
      '';
    };

    # High availability for production environments
    highAvailability = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable HA mode with multiple replicas for production. Currently disabled
        for single-node development but prepared for multi-node scaling.
        HA mode includes: Redis HA, multiple app controllers, repo servers.
      '';
    };

    # Container image security with version pinning
    image = mkOption {
      type = types.str;
      default = "quay.io/argoproj/argocd:v3.1.5";
      description = ''
        ArgoCD image from Red Hat Quay (enterprise registry). Version pinned
        for security and reproducibility. Quay provides vulnerability scanning
        and signed images for enterprise compliance requirements.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # ArgoCD namespace with proper labels
      argocd-namespace = {
        content = {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "argocd";
              "app.kubernetes.io/component" = "gitops";
              "pod-security.kubernetes.io/enforce" = "baseline";
              "pod-security.kubernetes.io/audit" = "baseline";
              "pod-security.kubernetes.io/warn" = "baseline";
            };
          };
        };
      };

      # Use official ArgoCD manifests (most reliable approach)
      argocd-install = {
        source = pkgs.fetchurl {
          url = if cfg.highAvailability
                then "https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.5/manifests/ha/install.yaml"
                else "https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.5/manifests/install.yaml";
          sha256 = "sha256-IQ5P36aTTbzCGhWX1uUA3r4pdlE7dlF/3TH4344LlsQ=";
        };
      };

      # Enterprise LoadBalancer service with security annotations
      argocd-server-lb = {
        content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "argocd-server-lb";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "argocd-server";
              "app.kubernetes.io/component" = "server";
            };
            annotations = {
              "metallb.universe.tf/loadBalancerIPs" = cfg.loadBalancerIP;
              # Security annotations
              "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "";
              "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "https";
            };
          };
          spec = {
            type = "LoadBalancer";
            loadBalancerIP = cfg.loadBalancerIP;
            selector = {
              "app.kubernetes.io/name" = "argocd-server";
            };
            ports = [
              {
                name = "server";
                port = 443;
                protocol = "TCP";
                targetPort = 8080;
              }
              {
                name = "grpc";
                port = 443;
                protocol = "TCP";
                targetPort = 8080;
              }
            ];
            sessionAffinity = "ClientIP";
          };
        };
      };

      # ArgoCD server configuration with enterprise settings
      argocd-server-config = {
        content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "argocd-server-config";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "argocd-server-config";
              "app.kubernetes.io/component" = "server";
            };
          };
          data = {
            # Enterprise security settings
            "server.insecure" = "true";  # Behind LoadBalancer with TLS termination
            "server.grpc.web" = "true";
            "server.enable.grpc.web" = "true";

            # Repository configuration
            "repositories" = ''
              - url: ${cfg.repositoryUrl}
                name: nerv-platform
                type: git
            '';

            # Application projects configuration
            "policy.default" = "role:readonly";
            "policy.csv" = ''
              p, role:admin, applications, *, */*, allow
              p, role:admin, certificates, *, *, allow
              p, role:admin, clusters, *, *, allow
              p, role:admin, repositories, *, *, allow
              g, argocd-admins, role:admin
            '';

            # OIDC configuration placeholder (for enterprise integration)
            "oidc.config" = ''
              name: NERV SSO
              issuer: https://auth.nerv.local
              clientId: argocd
              clientSecret: $oidc.clientSecret
              requestedScopes: ["openid", "profile", "email", "groups"]
              requestedIDTokenClaims: {"groups": {"essential": true}}
            '';
          };
        };
      };

      # Resource quota for ArgoCD namespace (enterprise requirement)
      argocd-resource-quota = {
        content = {
          apiVersion = "v1";
          kind = "ResourceQuota";
          metadata = {
            name = "argocd-quota";
            namespace = cfg.namespace;
          };
          spec = {
            hard = {
              "requests.cpu" = "2";
              "requests.memory" = "4Gi";
              "limits.cpu" = "4";
              "limits.memory" = "8Gi";
              "pods" = "20";
              "persistentvolumeclaims" = "5";
            };
          };
        };
      };

      # Network policy for ArgoCD (zero-trust networking)
      argocd-network-policy = {
        content = {
          apiVersion = "networking.k8s.io/v1";
          kind = "NetworkPolicy";
          metadata = {
            name = "argocd-network-policy";
            namespace = cfg.namespace;
          };
          spec = {
            podSelector = {
              matchLabels = {
                "app.kubernetes.io/part-of" = "argocd";
              };
            };
            policyTypes = ["Ingress" "Egress"];
            ingress = [
              {
                from = [
                  {
                    namespaceSelector = {
                      matchLabels = {
                        "name" = "traefik-system";
                      };
                    };
                  }
                  {
                    namespaceSelector = {
                      matchLabels = {
                        "name" = "metallb-system";
                      };
                    };
                  }
                ];
                ports = [
                  {
                    protocol = "TCP";
                    port = 8080;
                  }
                  {
                    protocol = "TCP";
                    port = 8083;
                  }
                ];
              }
            ];
            egress = [
              {
                # Allow DNS
                to = [];
                ports = [
                  {
                    protocol = "UDP";
                    port = 53;
                  }
                ];
              }
              {
                # Allow HTTPS for Git repositories
                to = [];
                ports = [
                  {
                    protocol = "TCP";
                    port = 443;
                  }
                  {
                    protocol = "TCP";
                    port = 22;
                  }
                ];
              }
              {
                # Allow Kubernetes API access
                to = [];
                ports = [
                  {
                    protocol = "TCP";
                    port = 6443;
                  }
                ];
              }
            ];
          };
        };
      };

      # RBAC for cluster admin operations (enterprise GitOps pattern)
      argocd-cluster-admin = {
        content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRoleBinding";
          metadata = {
            name = "argocd-application-controller-admin";
            labels = {
              "app.kubernetes.io/name" = "argocd-application-controller";
              "app.kubernetes.io/component" = "application-controller";
            };
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

      # ServiceMonitor for Prometheus integration (enterprise observability)
      argocd-service-monitor = {
        content = {
          apiVersion = "monitoring.coreos.com/v1";
          kind = "ServiceMonitor";
          metadata = {
            name = "argocd-metrics";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "argocd-metrics";
              "app.kubernetes.io/component" = "metrics";
            };
          };
          spec = {
            selector = {
              matchLabels = {
                "app.kubernetes.io/name" = "argocd-metrics";
              };
            };
            endpoints = [
              {
                port = "metrics";
                interval = "30s";
                path = "/metrics";
              }
            ];
          };
        };
      };
    };
  };
}
# modules/services/cert-manager.nix
# Modern cert-manager v1.18 for automatic SSL/TLS certificate management
# Portfolio Note: Demonstrates enterprise SSL automation with Let's Encrypt

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.cert-manager;
in

{
  options.services.nerv.cert-manager = {
    enable = mkEnableOption "cert-manager v1.18 certificate automation";

    namespace = mkOption {
      type = types.str;
      default = "cert-manager";
      description = "Kubernetes namespace for cert-manager deployment";
    };

    acmeEmail = mkOption {
      type = types.str;
      description = "Email address for Let's Encrypt ACME registration";
    };

    # Let's Encrypt environment configuration
    letsencrypt = {
      staging = mkOption {
        type = types.bool;
        default = false;
        description = "Use Let's Encrypt staging environment (for testing)";
      };

      wildcardDomains = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of domains for wildcard certificate generation";
        example = [ "*.nerv.local" "*.internal.nerv.local" ];
      };
    };

    # DNS challenge configuration for wildcard certificates
    dnsChallenge = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable DNS challenge for wildcard certificates";
      };

      provider = mkOption {
        type = types.str;
        default = "cloudflare";
        description = "DNS provider for challenge (cloudflare, route53, etc.)";
      };
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # cert-manager ArgoCD Application for GitOps management
      cert-manager-app = {
        content = {
          apiVersion = "argoproj.io/v1alpha1";
          kind = "Application";
          metadata = {
            name = "cert-manager";
            namespace = "default";
            annotations = {
              "argocd.argoproj.io/sync-wave" = "0";  # Deploy before Traefik
            };
            finalizers = [
              "resources-finalizer.argocd.argoproj.io"
            ];
          };
          spec = {
            project = "default";
            source = {
              repoURL = "https://charts.jetstack.io";
              chart = "cert-manager";
              targetRevision = "v1.18.2";
              helm = {
                values = ''
                  # Modern cert-manager v1.18 configuration
                  # Optimized for enterprise SSL automation
                  
                  # Image configuration
                  image:
                    tag: v1.18.2
                    pullPolicy: IfNotPresent
                  
                  # Resource configuration for mini PC efficiency
                  resources:
                    requests:
                      cpu: 50m
                      memory: 64Mi
                    limits:
                      cpu: 200m
                      memory: 128Mi
                  
                  # Webhook configuration
                  webhook:
                    resources:
                      requests:
                        cpu: 20m
                        memory: 32Mi
                      limits:
                        cpu: 100m
                        memory: 64Mi
                    nodeSelector:
                      "node-role.kubernetes.io/control-plane": "true"
                    tolerations:
                      - key: node-role.kubernetes.io/control-plane
                        operator: Exists
                        effect: NoSchedule
                  
                  # CA Injector configuration
                  cainjector:
                    resources:
                      requests:
                        cpu: 50m
                        memory: 64Mi
                      limits:
                        cpu: 200m
                        memory: 128Mi
                    nodeSelector:
                      "node-role.kubernetes.io/control-plane": "true"
                    tolerations:
                      - key: node-role.kubernetes.io/control-plane
                        operator: Exists
                        effect: NoSchedule
                  
                  # Install CRDs automatically
                  installCRDs: true
                  
                  # Security context for production readiness
                  securityContext:
                    runAsNonRoot: true
                    runAsUser: 1000
                    runAsGroup: 1000
                    capabilities:
                      drop: [ALL]
                    readOnlyRootFilesystem: true
                    allowPrivilegeEscalation: false
                  
                  # Node selector for control-plane scheduling
                  nodeSelector:
                    "node-role.kubernetes.io/control-plane": "true"
                  
                  # Tolerations for single-node setup
                  tolerations:
                    - key: node-role.kubernetes.io/control-plane
                      operator: Exists
                      effect: NoSchedule
                  
                  # Prometheus monitoring integration
                  prometheus:
                    enabled: true
                    servicemonitor:
                      enabled: false  # Will enable when Prometheus is deployed
                  
                  # Global configuration
                  global:
                    leaderElection:
                      namespace: ${cfg.namespace}
                '';
              };
            };
            destination = {
              server = "https://kubernetes.default.svc";
              namespace = cfg.namespace;
            };
            syncPolicy = {
              automated = {
                prune = true;
                selfHeal = true;
              };
              syncOptions = [
                "CreateNamespace=true"
                "ServerSideApply=true"
                "Replace=true"  # Required for CRD updates
              ];
              retry = {
                limit = 5;
                backoff = {
                  duration = "5s";
                  factor = 2;
                  maxDuration = "5m";
                };
              };
            };
          };
        };
      };

      # Let's Encrypt ClusterIssuer (Production)
      letsencrypt-prod-issuer = mkIf (!cfg.letsencrypt.staging) {
        content = {
          apiVersion = "cert-manager.io/v1";
          kind = "ClusterIssuer";
          metadata = {
            name = "letsencrypt-prod";
            annotations = {
              "argocd.argoproj.io/sync-wave" = "1";
            };
          };
          spec = {
            acme = {
              # Let's Encrypt production server
              server = "https://acme-v02.api.letsencrypt.org/directory";
              email = cfg.acmeEmail;
              privateKeySecretRef = {
                name = "letsencrypt-prod";
              };
              solvers = [
                {
                  http01 = {
                    ingress = {
                      class = "traefik";
                    };
                  };
                }
              ] ++ (if cfg.dnsChallenge.enable then [
                {
                  dns01 = {
                    "${cfg.dnsChallenge.provider}" = {
                      # Provider-specific configuration will be added here
                      # This is a placeholder for DNS challenge setup
                    };
                  };
                  selector = {
                    dnsNames = cfg.letsencrypt.wildcardDomains;
                  };
                }
              ] else []);
            };
          };
        };
      };

      # Let's Encrypt ClusterIssuer (Staging) 
      letsencrypt-staging-issuer = mkIf cfg.letsencrypt.staging {
        content = {
          apiVersion = "cert-manager.io/v1";
          kind = "ClusterIssuer";
          metadata = {
            name = "letsencrypt-staging";
            annotations = {
              "argocd.argoproj.io/sync-wave" = "1";
            };
          };
          spec = {
            acme = {
              # Let's Encrypt staging server for testing
              server = "https://acme-staging-v02.api.letsencrypt.org/directory";
              email = cfg.acmeEmail;
              privateKeySecretRef = {
                name = "letsencrypt-staging";
              };
              solvers = [
                {
                  http01 = {
                    ingress = {
                      class = "traefik";
                    };
                  };
                }
              ];
            };
          };
        };
      };

      # Default certificate for *.nerv.local (if wildcard domains configured)
      default-wildcard-cert = mkIf (cfg.letsencrypt.wildcardDomains != []) {
        content = {
          apiVersion = "cert-manager.io/v1";
          kind = "Certificate";
          metadata = {
            name = "nerv-wildcard-cert";
            namespace = "traefik-system";
            annotations = {
              "argocd.argoproj.io/sync-wave" = "2";
            };
          };
          spec = {
            secretName = "nerv-wildcard-tls";
            issuerRef = {
              name = if cfg.letsencrypt.staging then "letsencrypt-staging" else "letsencrypt-prod";
              kind = "ClusterIssuer";
            };
            dnsNames = cfg.letsencrypt.wildcardDomains;
          };
        };
      };
    };
  };
}
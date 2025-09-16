# modules/services/traefik.nix
# Modern Traefik v3.x ingress controller with GitOps integration
# Portfolio Note: Demonstrates cloud-native ingress with automatic SSL/TLS

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.traefik;
in

{
  options.services.nerv.traefik = {
    enable = mkEnableOption "Traefik v3.x ingress controller";

    loadBalancerIP = mkOption {
      type = types.str;
      default = "192.168.1.112";
      description = "LoadBalancer IP address for Traefik service";
    };

    namespace = mkOption {
      type = types.str;
      default = "traefik-system";
      description = "Kubernetes namespace for Traefik deployment";
    };

    # Dashboard configuration
    dashboard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Traefik dashboard with authentication";
      };

      hostname = mkOption {
        type = types.str;
        default = "traefik.nerv.local";
        description = "Hostname for Traefik dashboard access";
      };
    };

    # SSL/TLS configuration
    tls = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic SSL/TLS with cert-manager integration";
      };

      acmeEmail = mkOption {
        type = types.str;
        description = "Email address for Let's Encrypt ACME registration";
      };
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # Traefik CRDs - Modern approach with dedicated CRD management
      traefik-crds = {
        source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/traefik/traefik-helm-chart/v37.1.1/traefik/crds/traefik.io_ingressroutes.yaml";
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # Will be updated on rebuild
        };
      };

      # Traefik ArgoCD Application for GitOps management
      traefik-app = {
        content = {
          apiVersion = "argoproj.io/v1alpha1";
          kind = "Application";
          metadata = {
            name = "traefik";
            namespace = "default";
            annotations = {
              "argocd.argoproj.io/sync-wave" = "1";
            };
            finalizers = [
              "resources-finalizer.argocd.argoproj.io"
            ];
          };
          spec = {
            project = "default";
            source = {
              repoURL = "https://traefik.github.io/charts";
              chart = "traefik";
              targetRevision = "37.1.1";
              helm = {
                values = ''
                  # Modern Traefik v3.x configuration for NERV platform
                  # Optimized for single-node with enterprise features
                  
                  # Image configuration
                  image:
                    tag: "v3.5"
                    pullPolicy: IfNotPresent
                  
                  # Deployment configuration for mini PC efficiency
                  deployment:
                    replicas: 1
                    resources:
                      requests:
                        cpu: 100m
                        memory: 128Mi
                      limits:
                        cpu: 300m
                        memory: 256Mi
                  
                  # Service configuration with MetalLB integration
                  service:
                    type: LoadBalancer
                    spec:
                      loadBalancerIP: "${cfg.loadBalancerIP}"
                    annotations:
                      metallb.universe.tf/loadBalancerIPs: "${cfg.loadBalancerIP}"
                  
                  # Ingress controller configuration
                  ingressClass:
                    enabled: true
                    isDefaultClass: true
                    name: traefik
                  
                  # Modern providers configuration
                  providers:
                    kubernetesCRD:
                      enabled: true
                      allowCrossNamespace: true
                      allowExternalNameServices: true
                    kubernetesIngress:
                      enabled: true
                      allowExternalNameServices: true
                      publishedService:
                        enabled: true
                  
                  # Ports configuration for multiple protocols
                  ports:
                    web:
                      port: 8000
                      expose: true
                      exposedPort: 80
                      protocol: TCP
                      redirectTo: websecure
                    websecure:
                      port: 8443
                      expose: true
                      exposedPort: 443
                      protocol: TCP
                      tls:
                        enabled: true
                    traefik:
                      port: 9000
                      expose: false
                      protocol: TCP
                  
                  # Global configuration
                  globalArguments:
                    - "--global.checknewversion=false"
                    - "--global.sendanonymoususage=false"
                  
                  # Additional configuration for enterprise features
                  additionalArguments:
                    - "--log.level=INFO"
                    - "--accesslog=true"
                    - "--metrics.prometheus=true"
                    - "--metrics.prometheus.addEntryPointsLabels=true"
                    - "--metrics.prometheus.addServicesLabels=true"
                    - "--entrypoints.web.address=:8000"
                    - "--entrypoints.websecure.address=:8443"
                    - "--certificatesresolvers.letsencrypt.acme.email=${cfg.tls.acmeEmail}"
                    - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
                    - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
                  
                  # Persistence for ACME certificates
                  persistence:
                    enabled: true
                    size: 1Gi
                    path: /data
                    accessMode: ReadWriteOnce
                  
                  # Security context for production readiness
                  securityContext:
                    capabilities:
                      drop: [ALL]
                    readOnlyRootFilesystem: true
                    runAsGroup: 65532
                    runAsNonRoot: true
                    runAsUser: 65532
                  
                  podSecurityContext:
                    fsGroup: 65532
                    fsGroupChangePolicy: OnRootMismatch
                    runAsGroup: 65532
                    runAsNonRoot: true
                    runAsUser: 65532
                  
                  # Health checks and probes
                  readinessProbe:
                    failureThreshold: 1
                    initialDelaySeconds: 2
                    periodSeconds: 10
                    successThreshold: 1
                    timeoutSeconds: 2
                  
                  livenessProbe:
                    failureThreshold: 3
                    initialDelaySeconds: 2
                    periodSeconds: 10
                    successThreshold: 1
                    timeoutSeconds: 2
                  
                  # Node selector for control-plane scheduling
                  nodeSelector:
                    "node-role.kubernetes.io/control-plane": "true"
                  
                  # Tolerations for single-node setup
                  tolerations:
                    - key: node-role.kubernetes.io/control-plane
                      operator: Exists
                      effect: NoSchedule
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
              ];
              retry = {
                limit = 3;
                backoff = {
                  duration = "5s";
                  factor = 2;
                  maxDuration = "3m";
                };
              };
            };
          };
        };
      };

      # Traefik Dashboard IngressRoute (Modern CRD approach)
      traefik-dashboard = mkIf cfg.dashboard.enable {
        content = {
          apiVersion = "traefik.io/v1alpha1";
          kind = "IngressRoute";
          metadata = {
            name = "traefik-dashboard";
            namespace = cfg.namespace;
            annotations = {
              "argocd.argoproj.io/sync-wave" = "2";
            };
          };
          spec = {
            entryPoints = [ "websecure" ];
            routes = [
              {
                match = "Host(`${cfg.dashboard.hostname}`)";
                kind = "Rule";
                services = [
                  {
                    name = "api@internal";
                    kind = "TraefikService";
                  }
                ];
                middlewares = [
                  {
                    name = "dashboard-auth";
                    namespace = cfg.namespace;
                  }
                ];
              }
            ];
            tls = mkIf cfg.tls.enable {
              certResolver = "letsencrypt";
            };
          };
        };
      };

      # Dashboard authentication middleware
      traefik-dashboard-auth = mkIf cfg.dashboard.enable {
        content = {
          apiVersion = "traefik.io/v1alpha1";
          kind = "Middleware";
          metadata = {
            name = "dashboard-auth";
            namespace = cfg.namespace;
          };
          spec = {
            basicAuth = {
              secret = "traefik-dashboard-auth";
            };
          };
        };
      };
    };
  };
}
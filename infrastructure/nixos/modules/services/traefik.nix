# modules/services/traefik.nix
#
# Traefik v3.x Ingress Controller - Direct Kubernetes Manifests Approach
#
# LEARNING OBJECTIVE: This module demonstrates why direct manifests are often
# superior to complex Helm charts in production environments. By embedding
# Kubernetes YAML directly in NixOS modules, we achieve:
#
# 1. PREDICTABILITY: No Helm schema changes breaking deployments
# 2. TRANSPARENCY: Every resource is visible and version-controlled
# 3. INTEGRATION: Native NixOS configuration without external dependencies
# 4. SIMPLICITY: No ArgoCD-managing-ArgoCD recursion complexity
#
# DESIGN DECISION: We chose Traefik over NGINX Ingress because:
# - Better cloud-native architecture (dynamic configuration)
# - Built-in Let's Encrypt integration (reduces moving parts)
# - Lower resource footprint (important for mini PC hardware)
# - Superior debugging experience with dashboard UI
#
# ENTERPRISE PATTERN: Notice how we separate configuration (options) from
# implementation (config) - this is standard NixOS module architecture that
# allows for composition and reusability across different environments.

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.traefik;
in

{
  # Module options define the external interface - what other modules can configure
  options.services.nerv.traefik = {
    enable = mkEnableOption "Traefik v3.x ingress controller";

    # Fixed IP assignment prevents IP conflicts and enables predictable networking
    loadBalancerIP = mkOption {
      type = types.str;
      default = "192.168.1.112";
      description = ''
        Static IP assigned by MetalLB for Traefik LoadBalancer service.
        Must be within MetalLB IP pool range defined in network.nix.
        This ensures predictable external access point for all ingress traffic.
      '';
    };

    # Namespace isolation is a Kubernetes security best practice
    namespace = mkOption {
      type = types.str;
      default = "traefik-system";
      description = ''
        Dedicated namespace for Traefik components. Isolates ingress controller
        from application workloads and allows for granular RBAC policies.
        Follows Kubernetes principle of least privilege.
      '';
    };

    # Version pinning prevents unexpected upgrades in production
    image = mkOption {
      type = types.str;
      default = "traefik:v3.5";
      description = ''
        Traefik container image with explicit version tag. Never use 'latest'
        in production as it breaks reproducibility and can introduce
        unexpected breaking changes during pod restarts.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # Traefik namespace
      traefik-namespace = {
        content = {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "traefik";
              "app.kubernetes.io/component" = "ingress-controller";
            };
          };
        };
      };

      # Traefik CRDs (essential ones only)
      traefik-ingressroute-crd = {
        source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/traefik/traefik/v3.5/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml";
          sha256 = "sha256-TP+6dQprfQBgwY1bxQLvtub1VhHn+XQcKYVth8eJU88=";  # To be updated
        };
      };

      # Traefik RBAC
      traefik-service-account = {
        content = {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata = {
            name = "traefik";
            namespace = cfg.namespace;
          };
        };
      };

      traefik-cluster-role = {
        content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRole";
          metadata = {
            name = "traefik";
          };
          rules = [
            # CORE KUBERNETES RESOURCES: Essential cluster-wide permissions
            {
              apiGroups = [""];
              resources = ["services" "secrets" "endpoints" "configmaps"];
              verbs = ["get" "list" "watch"];
            }
            # NETWORK DISCOVERY: EndpointSlices for advanced load balancing
            {
              apiGroups = ["discovery.k8s.io"];
              resources = ["endpointslices"];
              verbs = ["get" "list" "watch"];
            }
            # STANDARD INGRESS RESOURCES: Native Kubernetes ingress support
            {
              apiGroups = ["extensions" "networking.k8s.io"];
              resources = ["ingresses" "ingressclasses"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = ["extensions" "networking.k8s.io"];
              resources = ["ingresses/status"];
              verbs = ["update"];
            }
            # TRAEFIK CRD RESOURCES: Complete Traefik custom resource access
            {
              apiGroups = ["traefik.io"];
              resources = [
                "ingressroutes"
                "ingressroutetcps" 
                "ingressrouteudps"
                "middlewares"
                "middlewaretcps"
                "tlsoptions"
                "tlsstores"
                "traefikservices"
                "serverstransports"
                "serverstransporttcps"
              ];
              verbs = ["get" "list" "watch"];
            }
          ];
        };
      };

      traefik-cluster-role-binding = {
        content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRoleBinding";
          metadata = {
            name = "traefik";
          };
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "traefik";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "traefik";
              namespace = cfg.namespace;
            }
          ];
        };
      };

      # Traefik deployment
      traefik-deployment = {
        content = {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "traefik";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "traefik";
              "app.kubernetes.io/component" = "ingress-controller";
            };
          };
          spec = {
            replicas = 1;
            selector = {
              matchLabels = {
                "app.kubernetes.io/name" = "traefik";
              };
            };
            template = {
              metadata = {
                labels = {
                  "app.kubernetes.io/name" = "traefik";
                };
              };
              spec = {
                serviceAccountName = "traefik";
                nodeSelector = {
                  "node-role.kubernetes.io/control-plane" = "true";
                };
                tolerations = [
                  {
                    key = "node-role.kubernetes.io/control-plane";
                    operator = "Exists";
                    effect = "NoSchedule";
                  }
                ];
                containers = [
                  {
                    name = "traefik";
                    image = cfg.image;
                    imagePullPolicy = "IfNotPresent";
                    args = [
                      "--api.dashboard=true"
                      "--api.insecure=true"
                      "--providers.kubernetescrd=true"
                      "--providers.kubernetesingress=true"
                      "--entrypoints.web.address=:80"
                      "--entrypoints.websecure.address=:443"
                      "--certificatesresolvers.letsencrypt.acme.email=admin@nerv.local"
                      "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
                      "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
                      "--log.level=INFO"
                      "--accesslog=true"
                      "--metrics.prometheus=true"
                    ];
                    ports = [
                      {
                        name = "web";
                        containerPort = 80;
                        protocol = "TCP";
                      }
                      {
                        name = "websecure";
                        containerPort = 443;
                        protocol = "TCP";
                      }
                      {
                        name = "dashboard";
                        containerPort = 8080;
                        protocol = "TCP";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "data";
                        mountPath = "/data";
                      }
                    ];
                    resources = {
                      requests = {
                        cpu = "100m";
                        memory = "128Mi";
                      };
                      limits = {
                        cpu = "300m";
                        memory = "256Mi";
                      };
                    };
                    securityContext = {
                      runAsNonRoot = true;
                      runAsUser = 65532;
                      runAsGroup = 65532;
                      readOnlyRootFilesystem = true;
                      capabilities = {
                        drop = ["ALL"];
                      };
                    };
                    livenessProbe = {
                      httpGet = {
                        path = "/ping";
                        port = 8080;
                      };
                      initialDelaySeconds = 10;
                      periodSeconds = 10;
                    };
                    readinessProbe = {
                      httpGet = {
                        path = "/ping";
                        port = 8080;
                      };
                      initialDelaySeconds = 5;
                      periodSeconds = 5;
                    };
                  }
                ];
                volumes = [
                  {
                    name = "data";
                    emptyDir = {};
                  }
                ];
              };
            };
          };
        };
      };

      # Traefik LoadBalancer service
      traefik-service = {
        content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "traefik";
            namespace = cfg.namespace;
            annotations = {
              "metallb.universe.tf/loadBalancerIPs" = cfg.loadBalancerIP;
            };
          };
          spec = {
            type = "LoadBalancer";
            loadBalancerIP = cfg.loadBalancerIP;
            selector = {
              "app.kubernetes.io/name" = "traefik";
            };
            ports = [
              {
                name = "web";
                port = 80;
                targetPort = "web";
                protocol = "TCP";
              }
              {
                name = "websecure";
                port = 443;
                targetPort = "websecure";
                protocol = "TCP";
              }
            ];
          };
        };
      };

      # Traefik dashboard service (internal)
      traefik-dashboard-service = {
        content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "traefik-dashboard";
            namespace = cfg.namespace;
          };
          spec = {
            selector = {
              "app.kubernetes.io/name" = "traefik";
            };
            ports = [
              {
                name = "dashboard";
                port = 8080;
                targetPort = "dashboard";
                protocol = "TCP";
              }
            ];
          };
        };
      };

      # IngressClass for Traefik
      traefik-ingress-class = {
        content = {
          apiVersion = "networking.k8s.io/v1";
          kind = "IngressClass";
          metadata = {
            name = "traefik";
            annotations = {
              "ingressclass.kubernetes.io/is-default-class" = "true";
            };
          };
          spec = {
            controller = "traefik.io/ingress-controller";
          };
        };
      };
    };
  };
}
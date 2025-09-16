# modules/services/longhorn.nix
#
# Distributed Block Storage for Kubernetes - Cloud Native Persistent Volumes
#
# LEARNING OBJECTIVE: This module demonstrates enterprise-grade distributed
# storage using Longhorn, which provides persistent volumes for Kubernetes
# without requiring external SAN or cloud storage. Key learning areas:
#
# 1. STORAGE ARCHITECTURE: Distributed replicated block storage across cluster nodes
# 2. DATA PROTECTION: Automatic replication, snapshots, and backup capabilities
# 3. OPERATIONAL MATURITY: Volume expansion, disaster recovery, and monitoring
# 4. CLOUD NATIVE DESIGN: Kubernetes-native storage provisioning and lifecycle
#
# WHY DISTRIBUTED STORAGE MATTERS:
# - Traditional storage requires expensive SAN hardware or cloud dependency
# - Applications need persistent data that survives pod restarts and migrations
# - Enterprise workloads require high availability and disaster recovery
# - Edge computing needs storage independence from centralized systems
#
# LONGHORN ADVANTAGES: Unlike other solutions, Longhorn provides complete
# storage independence while maintaining enterprise features like snapshots,
# backups, and volume expansion - essential for production workloads.

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.longhorn;
in

{
  options.services.nerv.longhorn = {
    enable = mkEnableOption "Longhorn distributed storage (direct manifests)";

    namespace = mkOption {
      type = types.str;
      default = "longhorn-system";
      description = ''
        Dedicated namespace for Longhorn storage system components. Isolation
        provides security boundaries and enables privileged operations required
        for direct disk access and storage management.
      '';
    };

    image = mkOption {
      type = types.str;
      default = "longhornio/longhorn-manager:v1.9.1";
      description = ''
        Longhorn manager image for storage orchestration. Version pinned for
        production stability. Manager coordinates volume lifecycle, replica
        placement, and storage node health monitoring.
      '';
    };

    loadBalancerIP = mkOption {
      type = types.str;
      default = "192.168.1.111";
      description = ''
        External IP for Longhorn web UI access. Provides visibility into:
        - Volume status and replica distribution
        - Storage node capacity and health
        - Backup and snapshot management
        - Performance metrics and troubleshooting
      '';
    };

    # Storage configuration for production workloads
    defaultReplicaCount = mkOption {
      type = types.int;
      default = 1;
      description = ''
        Default number of replicas per volume. Single-node clusters use 1,
        production clusters typically use 3 for high availability. Each
        replica is stored on a different node for fault tolerance.
      '';
    };

    storageClass = {
      name = mkOption {
        type = types.str;
        default = "longhorn";
        description = "Storage class name";
      };

      reclaimPolicy = mkOption {
        type = types.str;
        default = "Retain";
        description = "Reclaim policy for volumes";
      };

      allowVolumeExpansion = mkOption {
        type = types.bool;
        default = true;
        description = "Allow volume expansion";
      };

      isDefault = mkOption {
        type = types.bool;
        default = true;
        description = "Set as default storage class";
      };
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # Longhorn namespace
      longhorn-namespace = {
        content = {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "longhorn";
              "app.kubernetes.io/component" = "storage";
              "pod-security.kubernetes.io/enforce" = "privileged";
              "pod-security.kubernetes.io/audit" = "privileged";
              "pod-security.kubernetes.io/warn" = "privileged";
            };
          };
        };
      };

      # Use official Longhorn manifests (most reliable)
      longhorn-install = {
        source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/longhorn/longhorn/v1.9.1/deploy/longhorn.yaml";
          sha256 = "sha256-g77oFLzbAwzBYmxlWcAB8FOrAHX/FOcdAjFSfCQ0anU=";
        };
      };

      # Longhorn UI LoadBalancer service
      longhorn-frontend-lb = {
        content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "longhorn-frontend-lb";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "longhorn-ui";
              "app.kubernetes.io/component" = "frontend";
            };
            annotations = {
              "metallb.universe.tf/loadBalancerIPs" = cfg.loadBalancerIP;
            };
          };
          spec = {
            type = "LoadBalancer";
            loadBalancerIP = cfg.loadBalancerIP;
            selector = {
              "app" = "longhorn-ui";
            };
            ports = [
              {
                name = "http";
                port = 80;
                targetPort = 8000;
                protocol = "TCP";
              }
            ];
          };
        };
      };

      # Longhorn storage class
      longhorn-storage-class = {
        content = {
          apiVersion = "storage.k8s.io/v1";
          kind = "StorageClass";
          metadata = {
            name = cfg.storageClass.name;
            annotations = mkIf cfg.storageClass.isDefault {
              "storageclass.kubernetes.io/is-default-class" = "true";
            };
            labels = {
              "app.kubernetes.io/name" = "longhorn";
              "app.kubernetes.io/component" = "storage-class";
            };
          };
          provisioner = "driver.longhorn.io";
          allowVolumeExpansion = cfg.storageClass.allowVolumeExpansion;
          reclaimPolicy = cfg.storageClass.reclaimPolicy;
          volumeBindingMode = "Immediate";
          parameters = {
            "numberOfReplicas" = toString cfg.defaultReplicaCount;
            "staleReplicaTimeout" = "2880";
            "fromBackup" = "";
            "fsType" = "ext4";
            "dataLocality" = "disabled";
          };
        };
      };

      # Longhorn configuration (enterprise settings)
      longhorn-default-setting = {
        content = {
          apiVersion = "longhorn.io/v1beta2";
          kind = "Setting";
          metadata = {
            name = "default-replica-count";
            namespace = cfg.namespace;
          };
          spec = {
            value = toString cfg.defaultReplicaCount;
          };
        };
      };

      # Resource quota for Longhorn namespace
      longhorn-resource-quota = {
        content = {
          apiVersion = "v1";
          kind = "ResourceQuota";
          metadata = {
            name = "longhorn-quota";
            namespace = cfg.namespace;
          };
          spec = {
            hard = {
              "requests.cpu" = "1";
              "requests.memory" = "2Gi";
              "limits.cpu" = "2";
              "limits.memory" = "4Gi";
              "pods" = "50";
              "persistentvolumeclaims" = "100";
            };
          };
        };
      };

      # Network policy for Longhorn (enterprise security)
      longhorn-network-policy = {
        content = {
          apiVersion = "networking.k8s.io/v1";
          kind = "NetworkPolicy";
          metadata = {
            name = "longhorn-network-policy";
            namespace = cfg.namespace;
          };
          spec = {
            podSelector = {
              matchLabels = {
                "app.kubernetes.io/name" = "longhorn";
              };
            };
            policyTypes = ["Ingress" "Egress"];
            ingress = [
              {
                # Allow traffic from all namespaces for storage access
                from = [];
                ports = [
                  {
                    protocol = "TCP";
                    port = 8000;  # UI
                  }
                  {
                    protocol = "TCP";
                    port = 9500;  # Manager
                  }
                ];
              }
            ];
            egress = [
              {
                # Allow all egress for storage operations
                to = [];
              }
            ];
          };
        };
      };

      # ServiceMonitor for Prometheus integration
      longhorn-service-monitor = {
        content = {
          apiVersion = "monitoring.coreos.com/v1";
          kind = "ServiceMonitor";
          metadata = {
            name = "longhorn-prometheus-servicemonitor";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "longhorn";
              "app.kubernetes.io/component" = "metrics";
            };
          };
          spec = {
            selector = {
              matchLabels = {
                "app" = "longhorn-manager";
              };
            };
            endpoints = [
              {
                port = "manager";
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
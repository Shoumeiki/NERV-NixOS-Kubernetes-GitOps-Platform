# modules/services/cert-manager.nix
#
# Certificate Management Automation - Cloud Native TLS Certificate Lifecycle
#
# LEARNING OBJECTIVE: This module demonstrates enterprise-grade certificate
# management using cert-manager, the de facto standard for Kubernetes TLS
# automation. Key learning areas:
#
# 1. AUTOMATED TLS: Complete certificate lifecycle from issuance to renewal
# 2. ACME PROTOCOL: Integration with Let's Encrypt for free, trusted certificates
# 3. PRODUCTION READINESS: Staging vs production issuers for safe testing
# 4. INGRESS INTEGRATION: Seamless integration with Traefik ingress controller
#
# WHY AUTOMATED CERTIFICATE MANAGEMENT MATTERS:
# - Manual certificate management doesn't scale in modern cloud environments
# - Certificate expiry is a leading cause of production outages
# - Security compliance requires short-lived, regularly rotated certificates
# - Multi-service architectures need dozens or hundreds of certificates
#
# ENTERPRISE CERTIFICATE STRATEGY: This implementation provides both staging
# and production Let's Encrypt issuers, enabling safe testing of certificate
# workflows before applying to production domains.

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.nerv.cert-manager;
in

{
  options.services.nerv.cert-manager = {
    enable = mkEnableOption "cert-manager (direct manifests)";

    namespace = mkOption {
      type = types.str;
      default = "cert-manager";
      description = ''
        Dedicated namespace for certificate management components. Isolates
        cert-manager from other workloads and enables granular RBAC policies.
        Standard practice for critical infrastructure components.
      '';
    };

    acmeEmail = mkOption {
      type = types.str;
      description = ''
        Contact email for Let's Encrypt ACME registration. Required for:
        - Account creation and certificate issuance
        - Critical notifications about certificate problems
        - Rate limit management and abuse prevention
        - Recovery contact for account issues
      '';
    };

    image = mkOption {
      type = types.str;
      default = "quay.io/jetstack/cert-manager-controller:v1.18.2";
      description = ''
        cert-manager controller image from Red Hat Quay registry. Version
        pinned for reproducible deployments. Quay provides vulnerability
        scanning and enterprise-grade image distribution.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.k3s.manifests = {
      # DEPLOYMENT STRATEGY: Official manifests for maximum compatibility
      # Using upstream cert-manager YAML instead of Helm charts provides:
      # - Predictable resource definitions without template complexity
      # - Direct visibility into all Kubernetes objects being created
      # - Elimination of Helm as dependency and potential failure point
      # - Easier troubleshooting with standard kubectl commands
      cert-manager-manifests = {
        source = pkgs.fetchurl {
          url = "https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml";
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # To be updated
        };
      };

      # PRODUCTION CERTIFICATE ISSUER: Let's Encrypt production environment
      # This issuer creates trusted certificates but has strict rate limits:
      # - 50 certificates per registered domain per week
      # - 5 failed authorizations per account per hostname per hour
      letsencrypt-prod-issuer = {
        content = {
          apiVersion = "cert-manager.io/v1";
          kind = "ClusterIssuer";
          metadata = {
            name = "letsencrypt-prod";
          };
          spec = {
            acme = {
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
              ];
            };
          };
        };
      };

      # STAGING CERTIFICATE ISSUER: Let's Encrypt testing environment
      # Critical for development and testing - staging environment provides:
      # - Higher rate limits for testing (thousands vs 50 per week)
      # - Identical workflow to production but untrusted root CA
      # - Essential for validating certificate automation before production
      # - Prevents accidental rate limiting of production domains
      letsencrypt-staging-issuer = {
        content = {
          apiVersion = "cert-manager.io/v1";
          kind = "ClusterIssuer";
          metadata = {
            name = "letsencrypt-staging";
          };
          spec = {
            acme = {
              # Staging environment - higher limits, untrusted certificates
              server = "https://acme-staging-v02.api.letsencrypt.org/directory";
              email = cfg.acmeEmail;
              privateKeySecretRef = {
                name = "letsencrypt-staging";
              };
              solvers = [
                {
                  # HTTP-01 challenge through Traefik ingress controller
                  # This method validates domain ownership by serving a file
                  # at http://domain/.well-known/acme-challenge/token
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
    };
  };
}
# Infrastructure Services

Platform infrastructure services deployed via GitOps workflow.

## Structure

Services are organised as directories containing:
- Kubernetes manifests or Helm charts
- Kustomization overlays for environment-specific configuration
- Service-specific documentation

## Deployment

Services are automatically discovered and deployed by ArgoCD when committed to this directory.

## Planned Infrastructure Services

- Ingress controller (Traefik/NGINX)
- Certificate management (cert-manager)
- Monitoring stack (Prometheus/Grafana)
- Log aggregation (Loki/Fluentd)
- Service mesh (Istio/Linkerd)
- Storage provisioners

---

*"The beginning and the end are one and the same."* - Kaworu Nagisa
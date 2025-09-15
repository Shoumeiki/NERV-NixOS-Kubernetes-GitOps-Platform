# Applications

User applications deployed via GitOps workflow.

## Structure

Applications are organised as directories containing:
- Kubernetes manifests or Helm charts
- Kustomization overlays for environment-specific configuration
- Application-specific documentation

## Deployment

Applications are automatically discovered and deployed by ArgoCD when committed to this directory.

## Planned Applications

- Home automation services
- Development tools and dashboards  
- Media services
- Monitoring and observability tools

---

*"Anywhere can be paradise as long as you have the will to live."* - Rei Ayanami
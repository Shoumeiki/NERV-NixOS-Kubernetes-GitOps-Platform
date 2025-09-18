# Kubernetes Manifests

Flux v2-managed Kubernetes manifests for platform services.

## Services

Deployment order:
1. MetalLB - Load balancer (IP pool 192.168.1.111-150)
2. cert-manager - TLS certificate automation  
3. Traefik - Ingress controller
4. Longhorn - Distributed storage

## Access

| Service | IP | Dashboard |
|---------|----|-----------| 
| Traefik | 192.168.1.112 | `http://192.168.1.112:9000` |
| Longhorn | 192.168.1.113 | `http://192.168.1.113` |

## Structure

```
infrastructure/kubernetes/
├── flux-system/           # Flux configuration
├── sources/               # Helm repositories  
└── releases/              # Service definitions
    ├── metallb/
    ├── cert-manager/
    ├── traefik/
    └── longhorn/
```

## Deployment

Flux syncs these manifests from Git automatically. Services use official Helm charts with:
- Static IP allocation
- Web dashboards 
- Resource limits
- Single-node tolerations

---

*"The fate of destruction is also the joy of rebirth."* - Kaworu Nagisa
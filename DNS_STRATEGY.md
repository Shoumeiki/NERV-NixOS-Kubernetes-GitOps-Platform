# Enterprise DNS Strategy for NERV Platform

## Overview

Instead of jumping to external-dns automation, we're implementing proper DNS infrastructure with industry-standard ad-blocking capabilities.

## DNS Solution Options

### 1. AdGuard Home (Recommended)
**Pros:**
- Modern web interface with enterprise features
- DNS-over-HTTPS/TLS support
- Better performance than Pi-hole
- Active development and security updates
- Professional statistics and logging
- Built-in parental controls and safe browsing

**Use Cases:**
- Modern enterprise environments
- Teams wanting web-based management
- Organizations requiring detailed DNS analytics

### 2. CoreDNS + Blocklist Plugin
**Pros:**
- Cloud-native Kubernetes standard
- Lightweight and performant
- Highly configurable via code
- Better integration with Kubernetes DNS
- CNCF project with enterprise backing

**Use Cases:**
- Infrastructure-as-code environments
- Teams preferring configuration over UI
- Maximum integration with Kubernetes

### 3. Pi-hole (Alternative)
**Pros:**
- Well-known and stable
- Large community and blocklist ecosystem
- Simple setup

**Cons:**
- Older architecture
- Less performant than alternatives
- Not designed for enterprise use

## Current Implementation

I've created both AdGuard Home and CoreDNS configurations. **AdGuard Home is set as default** in the platform config.

### Architecture:

```
Internet → AdGuard Home → Upstream DNS (Cloudflare/Quad9)
   ↓
Internal Services (.nerv.local)
   ↓
Kubernetes CoreDNS (cluster.local)
```

### Network Flow:
1. **External DNS queries** → AdGuard Home (ad-blocking + caching)
2. **Internal .nerv.local queries** → AdGuard Home (local resolution)
3. **Kubernetes .cluster.local queries** → Default CoreDNS

## Deployment Options

### Option A: AdGuard Home (Current Default)
```bash
# Add to kustomization.yaml
- releases/adguard-home/helmrelease.yaml

# Access web interface at:
https://adguard.nerv.local
```

### Option B: CoreDNS with Ad-blocking
```bash
# Alternative: Use CoreDNS instead
- releases/coredns-adblock/helmrelease.yaml
```

## Configuration Management

All DNS settings centralized in `config/platform-config.yaml`:

```yaml
dns.server.type: "adguard-home"  # Switch between solutions
dns.upstream.primary: "1.1.1.1"
dns.upstream.secondary: "9.9.9.9"
dns.local.domain: "nerv.local"
```

## Enterprise Features

### Security
- DNS-over-HTTPS/TLS for encrypted queries
- Upstream DNS filtering (Cloudflare/Quad9)
- Query logging and analytics
- Malware and phishing protection

### Performance
- LoadBalancer service for network-wide DNS
- Persistent storage for configuration/logs
- Resource limits and monitoring
- High availability with anti-affinity

### Management
- Web interface for policy management
- GitOps configuration via Helm values
- Centralized blocklist management
- Integration with monitoring stack

## Next Steps

1. **Deploy AdGuard Home** - Provides immediate ad-blocking with web UI
2. **Configure client devices** - Point to AdGuard Home IP for network-wide filtering
3. **Add monitoring** - Integrate DNS metrics with Prometheus/Grafana
4. **Customize blocklists** - Add enterprise-specific filtering rules

This approach gives you enterprise-grade DNS with ad-blocking while maintaining the flexibility to evolve the solution as your needs grow.
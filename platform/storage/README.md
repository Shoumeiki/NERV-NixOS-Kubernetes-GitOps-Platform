# NERV Storage Architecture Decision

## Current Implementation: OpenEBS LocalPV (Recommended)

### Why OpenEBS Instead of Longhorn?

**Technical Reasoning:**
- **NixOS Compatibility**: OpenEBS LocalPV has better compatibility with NixOS's unique filesystem structure
- **Single-Node Optimized**: Designed for local storage scenarios, not distributed-first like Longhorn
- **Enterprise Features**: Still provides snapshots, monitoring, and dynamic provisioning
- **Simpler Dependencies**: Fewer host-level requirements and binary path issues

**Portfolio Value:**
- Demonstrates **pragmatic architecture decisions** based on platform constraints
- Shows understanding of **storage solution trade-offs**
- **Professional approach**: Choose the right tool for the job, not the trendy one

### Longhorn Implementation (Available)

The Longhorn configuration remains available in `longhorn-app.yaml` for future multi-node expansion:

**When to Use Longhorn:**
- **Multi-node clusters** (3+ nodes) where distributed storage benefits outweigh complexity
- **Cross-node replication** requirements for high availability
- **Backup to external storage** (S3, NFS) for disaster recovery

**Current Limitations with NixOS:**
- Complex binary path resolution issues
- Host dependency management complexity
- Single-node configuration stability challenges

### Migration Path

**Phase 1**: OpenEBS LocalPV for development and single-node production
**Phase 2**: Evaluate Longhorn when expanding to multi-node architecture
**Phase 3**: Implement distributed storage when business requirements justify complexity

## Usage

To switch between storage solutions:

```bash
# Enable OpenEBS (current default)
kubectl apply -f alternative-storage.yaml

# Enable Longhorn (for multi-node future)
kubectl apply -f longhorn-app.yaml
```

This approach demonstrates **DevOps maturity** by choosing appropriate solutions for current needs while maintaining future scalability options.
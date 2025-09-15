#!/usr/bin/env bash
# create-metallb-pool.sh
# Create MetalLB IP address pool

set -euo pipefail

echo "Creating MetalLB IP address pool..."

# Create IPAddressPool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: nerv-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.110-192.168.1.150
EOF

# Create L2Advertisement  
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: nerv-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - nerv-pool
EOF

echo "✓ MetalLB IP pool created successfully"
echo "IP Pool: 192.168.1.110-192.168.1.150"
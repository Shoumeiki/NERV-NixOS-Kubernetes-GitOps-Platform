#!/usr/bin/env bash
# bootstrap-metallb.sh
# Deploy MetalLB load balancer for external access

set -euo pipefail

echo "Bootstrapping MetalLB load balancer..."
echo "Using KUBECONFIG: ${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

# Wait for K3s API to be ready
echo "Waiting for Kubernetes API..."
timeout=60
while ! kubectl cluster-info >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
    sleep 2
    ((timeout--))
done

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "ERROR: Kubernetes API not ready after 60 seconds"
    exit 1
fi

# Check if MetalLB is already installed
if kubectl get namespace metallb-system >/dev/null 2>&1; then
    echo "MetalLB namespace already exists, checking deployment..."
    if kubectl get deployment controller -n metallb-system >/dev/null 2>&1; then
        echo "✓ MetalLB already installed"
        exit 0
    fi
fi

# Install MetalLB
echo "Installing MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
echo "Waiting for MetalLB controller..."
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=metallb \
    --timeout=300s

# Create IP address pool for your network
echo "Creating MetalLB IP address pool..."
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: nerv-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.110-192.168.1.150
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: nerv-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - nerv-pool
EOF

echo "✓ MetalLB load balancer installed successfully"
echo "IP Pool: 192.168.1.110-192.168.1.150"
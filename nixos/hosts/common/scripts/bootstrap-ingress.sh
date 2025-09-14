#!/usr/bin/env bash
# bootstrap-ingress.sh
# Configure Traefik ingress for ArgoCD external access

set -euo pipefail

echo "Bootstrapping ingress configuration..."
echo "Using KUBECONFIG: ${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

# Wait for MetalLB to be ready (dependency)
echo "Waiting for MetalLB to be available..."
timeout=60
while ! kubectl get namespace metallb-system >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
    sleep 2
    ((timeout--))
done

# Wait for ArgoCD to be ready (dependency)
echo "Waiting for ArgoCD to be available..."
timeout=60
while ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
    sleep 2
    ((timeout--))
done

# Create ArgoCD ingress with LoadBalancer service
echo "Creating ArgoCD LoadBalancer service..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-lb
  namespace: argocd
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.1.110
spec:
  type: LoadBalancer
  ports:
  - name: server
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: grpc
    port: 443
    targetPort: 8080
    protocol: TCP
  selector:
    app.kubernetes.io/name: argocd-server
EOF

echo "✓ ArgoCD ingress configuration completed"
echo "ArgoCD will be accessible at: http://192.168.1.110"
echo "Note: It may take a few minutes for the LoadBalancer IP to be assigned"
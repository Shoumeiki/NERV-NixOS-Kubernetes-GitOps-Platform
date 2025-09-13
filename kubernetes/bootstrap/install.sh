#!/usr/bin/env bash
# bootstrap/install.sh
# Bootstrap ArgoCD onto the cluster

set -euo pipefail

echo "Bootstrapping ArgoCD on NERV cluster..."

# Install ArgoCD using the official manifests
echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get the initial admin password
echo "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "✓ ArgoCD installed successfully!"
echo
echo "Access ArgoCD:"
echo "  Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo
echo "Note: Save this password - it's only shown once!"
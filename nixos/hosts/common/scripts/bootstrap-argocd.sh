#!/usr/bin/env bash
# bootstrap-argocd.sh
# Automatically bootstrap ArgoCD on K3s cluster

set -euo pipefail

export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

echo "Bootstrapping ArgoCD on NERV cluster..."

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

# Check if ArgoCD is already installed
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo "ArgoCD namespace already exists, checking deployment..."
    if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        echo "✓ ArgoCD already installed"
        exit 0
    fi
fi

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for deployment to be ready
echo "Waiting for ArgoCD deployment..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Patch ArgoCD server to be insecure (for internal cluster access)
kubectl patch deployment argocd-server -n argocd -p='{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","args":["argocd-server","--insecure"]}]}}}}'

echo "✓ ArgoCD bootstrap completed successfully"

# Output access information
echo
echo "ArgoCD is now running!"
echo "Access via: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo "Username: admin"
echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
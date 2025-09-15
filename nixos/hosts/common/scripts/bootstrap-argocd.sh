#!/usr/bin/env bash
# bootstrap-argocd.sh
# Automatically bootstrap ArgoCD on K3s cluster

set -euo pipefail

# KUBECONFIG is now set via systemd Environment
echo "Bootstrapping ArgoCD on NERV cluster..."
echo "Using KUBECONFIG: ${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

# Verify kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl not found in PATH"
    echo "PATH: $PATH"
    exit 1
fi

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

# Set custom admin password from SOPS
echo "Setting custom ArgoCD admin password..."
ADMIN_PASSWORD_FILE="/run/secrets/argocd-admin-password"
if [[ -f "$ADMIN_PASSWORD_FILE" ]] && [[ -s "$ADMIN_PASSWORD_FILE" ]]; then
    CUSTOM_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")
    
    # Create bcrypt hash of the password (ArgoCD uses bcrypt)
    PASSWORD_HASH=$(echo -n "$CUSTOM_PASSWORD" | kubectl exec -n argocd deployment/argocd-server -- argocd-util admin hash-password 2>/dev/null | tail -n 1 || echo "")
    
    if [[ -n "$PASSWORD_HASH" ]]; then
        # Update admin password
        kubectl patch secret argocd-secret -n argocd -p="{\"data\":{\"admin.password\":\"$(echo -n "$PASSWORD_HASH" | base64 -w0)\"}}"
        
        # Remove initial admin secret
        kubectl delete secret argocd-initial-admin-secret -n argocd --ignore-not-found=true
        
        echo "✓ Custom admin password configured"
    else
        echo "WARNING: Failed to hash password, using default"
    fi
else
    echo "WARNING: Custom password file not found, using default"
fi

echo "✓ ArgoCD bootstrap completed successfully"

# Output access information
echo
echo "ArgoCD is now running!"
echo "Username: admin"
if [[ -f "$ADMIN_PASSWORD_FILE" ]] && [[ -s "$ADMIN_PASSWORD_FILE" ]]; then
    echo "Password: <your custom password from SOPS>"
else
    echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi
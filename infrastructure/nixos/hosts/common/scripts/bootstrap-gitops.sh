#!/usr/bin/env bash
# bootstrap-gitops.sh
# Create the root ArgoCD Application that manages everything via GitOps

set -euo pipefail

echo "Bootstrapping NERV GitOps platform..."
echo "Using KUBECONFIG: ${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
timeout=300
while ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1 && [[ $timeout -gt 0 ]]; do
    echo "Waiting for ArgoCD... ($((300-timeout))/300)"
    sleep 5
    ((timeout-=5))
done

if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    echo "ERROR: ArgoCD not ready after 5 minutes"
    exit 1
fi

# Wait for ArgoCD server to be available
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Set custom admin password from SOPS if available
echo "Configuring ArgoCD admin password..."
ADMIN_PASSWORD_FILE="/run/secrets/argocd-admin-password"
if [[ -f "$ADMIN_PASSWORD_FILE" ]] && [[ -s "$ADMIN_PASSWORD_FILE" ]]; then
    CUSTOM_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")
    
    # Create bcrypt hash of the password
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

# Create the root Application that manages everything via GitOps
echo "Creating root GitOps application..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nerv-root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git
    targetRevision: HEAD
    path: bootstrap
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo "GitOps platform bootstrap completed successfully"
echo "ArgoCD UI: http://192.168.1.110"
echo "Username: admin"
if [[ -f "$ADMIN_PASSWORD_FILE" ]] && [[ -s "$ADMIN_PASSWORD_FILE" ]]; then
    echo "Password: configured via SOPS"
else
    echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi
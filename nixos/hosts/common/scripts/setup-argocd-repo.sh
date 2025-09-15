#!/usr/bin/env bash
# setup-argocd-repo.sh  
# Configure ArgoCD repository and initial applications

set -euo pipefail

echo "Setting up ArgoCD repository and applications..."

# Wait for ArgoCD to be fully ready
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Add the NERV repository to ArgoCD
echo "Adding NERV repository to ArgoCD..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nerv-platform-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git
  name: nerv-platform
EOF

# Create ArgoCD self-management application
echo "Creating ArgoCD self-managed application..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-self-managed
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Shoumeiki/NERV-NixOS-Kubernetes-GitOps-Platform.git
    path: kubernetes/bootstrap
    targetRevision: HEAD
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

echo "✓ ArgoCD repository and applications configured"
echo "Access ArgoCD at: http://192.168.1.110"
echo "Check the 'Applications' tab to see your GitOps workflow!"
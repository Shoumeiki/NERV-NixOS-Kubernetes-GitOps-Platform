#!/usr/bin/env bash
# File: infrastructure/nixos/hosts/common/scripts/setup-kubeconfig.sh
# Description: Configure kubectl access for non-root user with proper K3s integration
# Learning Focus: Kubernetes client configuration, user permissions, and secure cluster access

set -euo pipefail

USER="ellen"
USER_HOME="/home/${USER}"
KUBE_DIR="${USER_HOME}/.kube"
KUBECONFIG="${KUBE_DIR}/config"
K3S_CONFIG="/etc/rancher/k3s/k3s.yaml"

echo "Setting up kubectl for ${USER}..."

timeout=60
while [[ ! -f "${K3S_CONFIG}" ]] && [[ $timeout -gt 0 ]]; do
    sleep 1
    ((timeout--))
done

if [[ ! -f "${K3S_CONFIG}" ]]; then
    echo "ERROR: K3s configuration not available"
    exit 1
fi

mkdir -p "${KUBE_DIR}"
chown "${USER}:users" "${KUBE_DIR}"
chmod 700 "${KUBE_DIR}"

cp "${K3S_CONFIG}" "${KUBECONFIG}"
chown "${USER}:users" "${KUBECONFIG}"
chmod 600 "${KUBECONFIG}"

if [[ -f "${KUBECONFIG}" ]] && [[ -r "${KUBECONFIG}" ]]; then
    echo "kubectl configuration complete"
else
    echo "ERROR: kubectl configuration failed"
    exit 1
fi
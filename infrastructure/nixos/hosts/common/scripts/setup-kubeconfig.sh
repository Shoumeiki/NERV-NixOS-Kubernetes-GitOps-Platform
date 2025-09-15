#!/usr/bin/env bash
# setup-kubeconfig.sh
# Automatically configure kubectl access for Ellen

set -euo pipefail

USER="ellen"
USER_HOME="/home/${USER}"
KUBE_DIR="${USER_HOME}/.kube"
KUBECONFIG="${KUBE_DIR}/config"
K3S_CONFIG="/etc/rancher/k3s/k3s.yaml"

echo "Setting up kubectl access for ${USER}..."

# Wait for K3s to be ready
echo "Waiting for K3s configuration..."
timeout=60
while [[ ! -f "${K3S_CONFIG}" ]] && [[ $timeout -gt 0 ]]; do
    sleep 1
    ((timeout--))
done

if [[ ! -f "${K3S_CONFIG}" ]]; then
    echo "ERROR: K3s configuration not found after 60 seconds"
    exit 1
fi

# Create .kube directory
echo "Creating .kube directory..."
mkdir -p "${KUBE_DIR}"
chown "${USER}:users" "${KUBE_DIR}"
chmod 700 "${KUBE_DIR}"

# Copy kubeconfig
echo "Copying kubeconfig..."
cp "${K3S_CONFIG}" "${KUBECONFIG}"
chown "${USER}:users" "${KUBECONFIG}"
chmod 600 "${KUBECONFIG}"

# Verify setup
if [[ -f "${KUBECONFIG}" ]] && [[ -r "${KUBECONFIG}" ]]; then
    echo "kubectl configuration ready for ${USER}"
else
    echo "ERROR: Failed to set up kubeconfig"
    exit 1
fi

echo "kubectl access configured successfully"
#!/usr/bin/env bash
# infrastructure/nixos/hosts/common/scripts/setup-kubeconfig.sh
#
# NERV Kubernetes Administrative Access Configuration
#
# LEARNING OBJECTIVE: This script demonstrates automated kubectl configuration
# for administrative users in enterprise Kubernetes environments. Key learning areas:
#
# 1. KUBERNETES CLIENT SETUP: Automated kubeconfig distribution for cluster access
# 2. SERVICE INTEGRATION: Coordinated startup with K3s cluster initialization
# 3. SECURITY BOUNDARIES: Proper file permissions and user access controls
# 4. OPERATIONAL READINESS: Ensuring administrative tools are immediately available
#
# WHY AUTOMATED KUBECONFIG SETUP:
# - Eliminates manual kubectl configuration after cluster deployment
# - Ensures immediate administrative access to newly deployed clusters
# - Maintains security through proper file ownership and permissions
# - Supports automated bootstrap workflows and operational procedures
#
# ENTERPRISE PATTERN: Administrative access must be both secure and immediately
# available. This script bridges K3s cluster initialization with user-space
# kubectl configuration, enabling seamless cluster management workflows.

set -euo pipefail

# ADMINISTRATIVE USER: Target user for kubectl access configuration
# Ellen - Platform administrator with cluster management responsibilities
USER="ellen"
USER_HOME="/home/${USER}"
KUBE_DIR="${USER_HOME}/.kube"
KUBECONFIG="${KUBE_DIR}/config"

# KUBERNETES CLUSTER ACCESS: K3s default configuration location
# K3s stores cluster configuration in /etc/rancher/k3s/k3s.yaml with cluster certificates
K3S_CONFIG="/etc/rancher/k3s/k3s.yaml"

echo "NERV Kubernetes Access Setup - Configuring kubectl for ${USER}..."

# ============================================================================
# SERVICE READINESS SYNCHRONIZATION: Wait for K3s cluster initialization
# ============================================================================

echo "Waiting for K3s cluster initialization..."

# CLUSTER READINESS POLLING: Monitor K3s configuration file availability
# The k3s.yaml file is created when the cluster is fully initialized and ready
timeout=60  # Maximum wait time in seconds
wait_count=0

while [[ ! -f "${K3S_CONFIG}" ]] && [[ $timeout -gt 0 ]]; do
    sleep 1
    ((timeout--))
    ((wait_count++))

    # PROGRESS INDICATION: Provide feedback during long initialization
    if (( wait_count % 10 == 0 )); then
        echo "Still waiting for K3s... (${wait_count}s elapsed)"
    fi
done

# INITIALIZATION TIMEOUT HANDLING: Detect K3s startup failures
if [[ ! -f "${K3S_CONFIG}" ]]; then
    echo "ERROR: K3s configuration not available after 60 seconds"
    echo "   This indicates K3s service failed to start properly."
    echo "   Common causes:"
    echo "   - System resource constraints (memory, disk space)"
    echo "   - Network configuration issues"
    echo "   - Container runtime initialization failure"
    echo "   - Port conflicts with existing services"
    echo ""
    echo "Troubleshooting commands:"
    echo "   systemctl status k3s"
    echo "   journalctl -u k3s -n 50"
    exit 1
fi

# CONFIGURATION VALIDATION: Verify K3s config file is readable and complete
if [[ ! -r "${K3S_CONFIG}" ]]; then
    echo "ERROR: K3s configuration exists but is not readable"
    echo "   Check file permissions: ls -la ${K3S_CONFIG}"
    exit 1
fi

echo "K3s cluster configuration available"

echo "Preparing kubectl configuration directory..."

# KUBE DIRECTORY CREATION: Standard kubectl configuration directory
# ~/.kube is the default location kubectl searches for configuration files
mkdir -p "${KUBE_DIR}"

# DIRECTORY OWNERSHIP: Ensure user owns their kubectl configuration directory
# Prevents privilege escalation and ensures proper access control
chown "${USER}:users" "${KUBE_DIR}"

# DIRECTORY PERMISSIONS: Restrict access to owner only for security
# 700 permissions (rwx------) prevent other users from accessing cluster credentials
chmod 700 "${KUBE_DIR}"

echo "kubectl directory prepared: ${KUBE_DIR}"

echo "Deploying cluster configuration..."

# KUBECONFIG COPY: Transfer K3s cluster configuration to user space
# This operation copies cluster certificates, server endpoints, and authentication data
cp "${K3S_CONFIG}" "${KUBECONFIG}"

# CONFIG FILE OWNERSHIP: Ensure user owns their kubeconfig file
# Proper ownership is required for kubectl to access the configuration
chown "${USER}:users" "${KUBECONFIG}"

# CONFIG FILE PERMISSIONS: Restrict kubeconfig access to owner only
# 600 permissions (rw-------) protect cluster credentials from unauthorized access
chmod 600 "${KUBECONFIG}"

echo "Cluster configuration deployed to user space"

echo "Validating kubectl configuration..."

# FILE ACCESSIBILITY CHECK: Ensure kubeconfig is properly accessible
if [[ -f "${KUBECONFIG}" ]] && [[ -r "${KUBECONFIG}" ]]; then

    # FILE DETAILS REPORTING: Provide configuration summary for verification
    config_size=$(stat -f%z "${KUBECONFIG}" 2>/dev/null || stat -c%s "${KUBECONFIG}" 2>/dev/null || echo "unknown")
    config_perms=$(ls -la "${KUBECONFIG}" | awk '{print $1}')

    echo "kubectl configuration validated successfully:"
    echo "   • User: ${USER}"
    echo "   • Config file: ${KUBECONFIG}"
    echo "   • File size: ${config_size} bytes"
    echo "   • Permissions: ${config_perms}"
    echo "   • Owner: $(ls -la "${KUBECONFIG}" | awk '{print $3":"$4}')"

else
    # CONFIGURATION FAILURE HANDLING: Detailed error reporting
    echo "ERROR: kubectl configuration validation failed"
    echo "   Configuration file status:"
    echo "   - File exists: $([[ -f "${KUBECONFIG}" ]] && echo "Yes" || echo "No")"
    echo "   - File readable: $([[ -r "${KUBECONFIG}" ]] && echo "Yes" || echo "No")"
    echo "   - File permissions: $(ls -la "${KUBECONFIG}" 2>/dev/null | awk '{print $1}' || echo "N/A")"
    echo ""
    echo "Manual verification: ls -la ${KUBE_DIR}/"
    exit 1
fi

echo "Kubernetes administrative access configured successfully"
echo ""
echo "Ready for cluster management operations:"
echo "   • Switch to user: su - ${USER}"
echo "   • Test cluster access: kubectl cluster-info"
echo "   • View cluster nodes: kubectl get nodes"
echo "   • Monitor deployments: kubectl get pods --all-namespaces"
echo ""
echo "Administrative user '${USER}' now has full kubectl access to the NERV cluster"
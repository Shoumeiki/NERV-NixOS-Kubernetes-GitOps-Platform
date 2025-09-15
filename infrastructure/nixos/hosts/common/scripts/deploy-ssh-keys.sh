#!/usr/bin/env bash
# deploy-ssh-keys.sh
# Deploy SSH keys from SOPS secrets

set -euo pipefail

# Configuration
USER="ellen"
USER_HOME="/home/${USER}"
SSH_DIR="${USER_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
SOPS_KEY_PATH="$1"  # Passed from systemd service

echo "Starting SSH key deployment for ${USER}..."

# Create .ssh directory
echo "Creating SSH directory..."
mkdir -p "${SSH_DIR}"
chown "${USER}:users" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# Check SOPS secret exists
if [[ ! -f "${SOPS_KEY_PATH}" ]]; then
    echo "ERROR: SOPS secret not found at ${SOPS_KEY_PATH}"
    exit 1
fi

echo "Deploying keys..."

# Copy SSH keys
cp "${SOPS_KEY_PATH}" "${AUTHORIZED_KEYS}"
chown "${USER}:users" "${AUTHORIZED_KEYS}"
chmod 600 "${AUTHORIZED_KEYS}"

# Verify
if [[ -f "${AUTHORIZED_KEYS}" ]] && [[ -s "${AUTHORIZED_KEYS}" ]]; then
    key_count=$(wc -l < "${AUTHORIZED_KEYS}")
    echo "Deployed ${key_count} key(s)"

    # Show key types for verification
    while IFS= read -r line; do
        if [[ ${line} =~ ^ssh- ]]; then
            echo "  $(echo "${line}" | cut -d' ' -f1,2 | head -c 40)..."
        fi
    done < "${AUTHORIZED_KEYS}"
else
    echo "ERROR: Deployment failed - authorized_keys empty"
    exit 1
fi

echo "SSH keys deployed successfully"
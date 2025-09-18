#!/usr/bin/env bash
# File: infrastructure/nixos/hosts/common/scripts/deploy-ssh-keys.sh
# Description: Deploy SSH public keys from SOPS-encrypted secrets to user authorized_keys
# Learning Focus: Secure SSH key management with SOPS integration and proper file permissions

set -euo pipefail

USER="ellen"
SSH_DIR="/home/${USER}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
SOPS_KEY_PATH="$1"

echo "Deploying SSH keys for ${USER}..."

mkdir -p "${SSH_DIR}"
chown "${USER}:users" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [[ ! -f "${SOPS_KEY_PATH}" ]]; then
    echo "ERROR: SOPS secret not found at ${SOPS_KEY_PATH}"
    exit 1
fi

cp "${SOPS_KEY_PATH}" "${AUTHORIZED_KEYS}"
chown "${USER}:users" "${AUTHORIZED_KEYS}"
chmod 600 "${AUTHORIZED_KEYS}"

if [[ -f "${AUTHORIZED_KEYS}" ]] && [[ -s "${AUTHORIZED_KEYS}" ]]; then
    key_count=$(wc -l < "${AUTHORIZED_KEYS}")
    echo "Successfully deployed ${key_count} SSH key(s)"
else
    echo "ERROR: SSH key deployment failed"
    exit 1
fi
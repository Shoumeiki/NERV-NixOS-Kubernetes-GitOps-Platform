#!/usr/bin/env bash
# infrastructure/nixos/hosts/common/scripts/deploy-ssh-keys.sh
#
# NERV SSH Key Deployment Automation
#
# LEARNING OBJECTIVE: This script demonstrates enterprise-grade SSH key management
# integrated with SOPS encrypted secret distribution. Key learning areas:
#
# 1. SECURE KEY DEPLOYMENT: Automated SSH key distribution from encrypted sources
# 2. PERMISSION HARDENING: Strict Unix permissions for SSH security compliance
# 3. SERVICE INTEGRATION: Designed for systemd service execution during boot
# 4. OPERATIONAL VERIFICATION: Built-in validation and logging for troubleshooting
#
# WHY AUTOMATED SSH KEY DEPLOYMENT:
# - Eliminates manual key distribution in infrastructure-as-code deployments
# - Ensures consistent security permissions across all nodes
# - Integrates with SOPS-nix for encrypted secret management
# - Provides audit trail and verification of deployed keys
#
# ENTERPRISE PATTERN: SSH key deployment must be both secure and automated.
# This script balances security (strict permissions, verification) with
# operational efficiency (automated deployment, clear logging).

set -euo pipefail

# ADMINISTRATIVE USER: Target user for SSH key deployment
# Ellen Ripley - Administrative user with sudo privileges for platform management
USER="ellen"
USER_HOME="/home/${USER}"
SSH_DIR="${USER_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

# SOPS INTEGRATION: Encrypted secret file path from systemd service parameter
# This path contains the decrypted SSH public keys from SOPS-nix
SOPS_KEY_PATH="$1"  # Passed from systemd service ExecStart parameter

echo "NERV SSH Key Deployment - Starting deployment for ${USER}..."

echo "Creating SSH directory structure..."

# SSH DIRECTORY CREATION: Standard SSH directory with proper ownership
# The .ssh directory must exist before key deployment and have restrictive permissions
mkdir -p "${SSH_DIR}"

# OWNERSHIP ASSIGNMENT: Ensure user owns their SSH directory
# Prevents privilege escalation and ensures proper access control
chown "${USER}:users" "${SSH_DIR}"

# PERMISSION HARDENING: Restrict SSH directory access to owner only
# 700 permissions (rwx------) prevent other users from accessing SSH configuration
chmod 700 "${SSH_DIR}"

echo "Validating SOPS secret availability..."

# SOPS SECRET VERIFICATION: Ensure decrypted key file exists and is readable
# This validation prevents deployment failures due to SOPS decryption issues
if [[ ! -f "${SOPS_KEY_PATH}" ]]; then
    echo "ERROR: SOPS secret not found at ${SOPS_KEY_PATH}"
    echo "   This usually indicates:"
    echo "   - SOPS-nix service failed to decrypt secrets"
    echo "   - Age private key not properly deployed"
    echo "   - Secret file path misconfiguration"
    exit 1
fi

# FILE READABILITY CHECK: Ensure the decrypted secret is accessible
if [[ ! -r "${SOPS_KEY_PATH}" ]]; then
    echo "ERROR: SOPS secret not readable at ${SOPS_KEY_PATH}"
    echo "   Check file permissions and SELinux/AppArmor policies"
    exit 1
fi

echo "SOPS secret validated successfully"

echo "Deploying SSH keys..."

# SSH KEY DEPLOYMENT: Copy decrypted keys to authorized_keys
# This operation transfers the SOPS-decrypted public keys to the standard SSH location
cp "${SOPS_KEY_PATH}" "${AUTHORIZED_KEYS}"

# KEY FILE OWNERSHIP: Ensure user owns their authorized_keys file
# Proper ownership is critical for SSH daemon to trust the key file
chown "${USER}:users" "${AUTHORIZED_KEYS}"

# KEY FILE PERMISSIONS: Restrict authorized_keys to owner read/write only
# 600 permissions (rw-------) are required by SSH daemon for security
chmod 600 "${AUTHORIZED_KEYS}"

echo "Verifying deployment..."

# FILE EXISTENCE AND SIZE CHECK: Ensure authorized_keys was created and populated
# Both conditions must be true for a successful deployment
if [[ -f "${AUTHORIZED_KEYS}" ]] && [[ -s "${AUTHORIZED_KEYS}" ]]; then

    # KEY COUNTING: Report number of deployed keys for audit purposes
    key_count=$(wc -l < "${AUTHORIZED_KEYS}")
    echo "Successfully deployed ${key_count} SSH key(s)"

    # KEY TYPE IDENTIFICATION: Display key types and truncated fingerprints
    # This provides verification without exposing full key content in logs
    echo "Deployed key summary:"
    while IFS= read -r line; do
        # SSH KEY FORMAT DETECTION: Identify valid SSH public key lines
        if [[ ${line} =~ ^ssh- ]]; then
            # KEY FINGERPRINT DISPLAY: Show key type and truncated key for verification
            # Format: "ssh-rsa AAAAB3NzaC1yc2EAAAA..." -> "ssh-rsa AAAAB3NzaC1yc2EAAAA..."
            echo "  ✓ $(echo "${line}" | cut -d' ' -f1,2 | head -c 40)..."
        fi
    done < "${AUTHORIZED_KEYS}"

else
    # DEPLOYMENT FAILURE HANDLING: Provide detailed error information
    echo "ERROR: SSH key deployment failed"
    echo "   Authorized keys file status:"
    echo "   - Exists: $([[ -f "${AUTHORIZED_KEYS}" ]] && echo "Yes" || echo "No")"
    echo "   - Non-empty: $([[ -s "${AUTHORIZED_KEYS}" ]] && echo "Yes" || echo "No")"
    echo "   - Permissions: $(ls -la "${AUTHORIZED_KEYS}" 2>/dev/null || echo "N/A")"
    exit 1
fi

echo "SSH key deployment completed successfully"
echo "   • User: ${USER}"
echo "   • Keys: ${key_count}"
echo "   • File: ${AUTHORIZED_KEYS}"
echo "   • Permissions: $(ls -la "${AUTHORIZED_KEYS}" | awk '{print $1}')"
echo ""
echo "SSH access is now configured for infrastructure management"
echo "   Test connection: ssh ${USER}@<target-ip>"
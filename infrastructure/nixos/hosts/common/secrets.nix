# File: infrastructure/nixos/hosts/common/secrets.nix
# Description: SOPS-encrypted secret management for passwords, keys, and tokens
# Learning Focus: Secret management with SOPS, file permissions, and security practices

{ config, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;  # Main encrypted secrets file
    age.keyFile = "/var/lib/sops-nix/key.txt";     # Age encryption key location

    # Define secrets with appropriate file permissions and ownership
    secrets = {
      # User authentication secrets
      "ellen/hashedPassword" = {
        neededForUsers = true;  # Required during user creation
        name = "ellen-hashedPassword";
        owner = "root";
        group = "root";
        mode = "0400";  # Read-only for root
      };

      "ellen/sshKey" = {
        name = "ellen-sshKey";
        owner = "root";
        group = "root";
        mode = "0444";
      };

      # Kubernetes cluster secrets
      "k3s/token" = {
        name = "k3s-token";
        owner = "root";
        group = "root";
        mode = "0400";  # Secure cluster join token
      };

      # GitOps application secrets
      "flux/gitToken" = {
        name = "flux-git-token";
        owner = "root";
        group = "root";
        mode = "0400";  # Flux v2 Git repository access token
      };

      # Additional secrets can be added here as needed
    };
  };
}
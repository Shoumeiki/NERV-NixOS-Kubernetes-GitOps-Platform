# hosts/common/secrets.nix
# NERV Cluster - Secret Management
#
# Simple, load-order-safe secret management using SOPS-nix
# This module only defines where secrets are located and how to access them
# It doesn't contain any actual secrets - those are in the encrypted files

{ config, ... }:

{
  # SOPS configuration - minimal and safe
  sops = {
    # Default secret file location (relative to flake root)
    defaultSopsFile = ../../secrets/secrets.yaml;
    
    # Where to place the age private key on deployed systems
    # This will be handled by nixos-anywhere during deployment
    age.keyFile = "/var/lib/sops-nix/key.txt";
    
    # Define which secrets to extract and where to place them
    secrets = {
      # Ellen's password hash
      "ellen/hashedPassword" = {
        # Make this available to the user configuration
        # Path will be /run/secrets/ellen-hashedPassword
        name = "ellen-hashedPassword";
        # Only root can read password hashes
        owner = "root";
        group = "root";
        mode = "0400";
      };
      
      # Ellen's SSH keys
      "ellen/sshKey" = {
        # Make this available to the SSH configuration
        name = "ellen-sshKey";
        # SSH service needs to read this
        owner = "root";
        group = "root";
        mode = "0444";
      };
    };
  };
}
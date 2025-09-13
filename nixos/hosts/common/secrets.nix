# hosts/common/secrets.nix
# SOPS secret management configuration

{ config, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";  # nixos-anywhere places key here
    
    secrets = {
      "ellen/hashedPassword" = {
        neededForUsers = true;  # Required for user creation
        name = "ellen-hashedPassword";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      
      "ellen/sshKey" = {
        name = "ellen-sshKey";
        owner = "root";
        group = "root";
        mode = "0444";
      };

      "k3s/token" = {
        name = "k3s-token";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };
}
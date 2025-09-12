# flake.nix
# NERV Kubernetes Cluster - Deployment Configuration
#
# This flake is used to deploy NixOS configurations to remote headless nodes.
# The nodes will automatically configure themselves upon deployment without
# requiring any manual intervention or additional tools on the target systems.
#
# Usage: nix flake show to see available configurations

{
  description = "NERV - NixOS Kubernetes Platform";

  # External dependencies for remote deployment
  inputs = {
    # Base NixOS packages - stable release for production reliability
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Declarative disk partitioning for automated setup
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secret management with age encryption
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }@inputs:
  let
    # Target architecture for all NERV cluster nodes
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # Define all NERV cluster nodes
    # Add new node names here and they will automatically get their configuration
    # from ./hosts/${nodeName}/ directory
    nodes = [
      "misato"  # Control node
    ];

    # Generate nixosConfiguration for each node
    mkNodeConfig = nodeName: {
      name = nodeName;
      value = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/common/global.nix    # Shared configuration for all nodes
          ./hosts/${nodeName}          # Node-specific configuration
          disko.nixosModules.disko     # Automated disk partitioning
          sops-nix.nixosModules.sops   # Secret management
        ];
      };
    };

  in
  {
    # Remote deployment configurations
    # Each configuration represents a complete system that can be deployed
    # to a fresh machine and will self-configure without intervention
    nixosConfigurations = builtins.listToAttrs (map mkNodeConfig nodes);

    # Local development environment for managing deployments
    # This shell provides tools needed to deploy and validate configurations
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        git            # Version control
        nixos-rebuild  # Local testing and validation
      ];

      shellHook = ''
        echo "NERV Command Centre"
        echo "Available commands:"
        echo "  nix flake check                        # Validate configurations"
        echo "  nix flake show                         # List available systems"
        echo "  nixos-rebuild build --flake .#misato   # Test build locally"
      '';
    };

    # Code formatting for consistent style
    formatter.${system} = pkgs.nixpkgs-fmt;
  };
}
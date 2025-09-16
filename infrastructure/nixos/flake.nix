# infrastructure/nixos/flake.nix
# NERV Platform NixOS Configuration

{
  description = ''
    NERV - NixOS Kubernetes GitOps Platform

    A production-ready Kubernetes infrastructure built on NixOS with:
    - Modular service architecture for maintainability
    - GitOps workflow via ArgoCD integration
    - Automated deployment with nixos-anywhere
    - SOPS-Nix secret management
    - MetalLB load balancing for bare metal
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Encrypted secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # NERV node inventory - add new nodes here
    nodes = [ "misato" ];

    # Node configuration builder with modular architecture
    mkNodeConfig = nodeName: {
      name = nodeName;
      value = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Core platform modules
          ./modules/network.nix      # Centralized network configuration
          ./modules/base-system.nix  # Base system packages and services
          ./modules/users.nix        # User management with SOPS integration
          ./modules/node-roles.nix   # Scalable node role definitions

          # Kubernetes service modules
          ./modules/services/argocd.nix   # GitOps workflow management
          ./modules/services/metallb.nix  # Load balancer for bare metal
          ./modules/services/longhorn.nix # Distributed storage system

          # Node-specific configurations
          ./hosts/common/secrets.nix # SOPS secret management
          ./hosts/${nodeName}        # Individual node configuration

          # External modules
          disko.nixosModules.disko   # Declarative disk management
          sops-nix.nixosModules.sops # Secret management
        ];
      };
    };

  in
  {
    nixosConfigurations = builtins.listToAttrs (map mkNodeConfig nodes);

    # Development environment with deployment tools
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Core tools
        git
        nixos-rebuild

        # Deployment tools
        nixos-anywhere

        # Secret management
        age
        sops

        # Kubernetes management
        kubectl

        # Development utilities
        nixpkgs-fmt
      ];

      shellHook = ''
        echo "NERV Development Environment"
        echo ""
        echo "Available Commands:"
        echo "  nix flake check                           # Validate all configurations"
        echo "  nix flake show                            # List available systems"
        echo "  nixos-rebuild build --flake .#misato      # Test build configuration"
        echo "  nixos-anywhere --flake .#misato root@IP   # Deploy to target system"
        echo ""
        echo "Secret Management:"
        echo "  sops -e secrets/secrets.yaml             # Edit encrypted secrets"
        echo "  sops -d secrets/secrets.yaml             # Decrypt and view secrets"
        echo ""
        echo "Kubernetes Management:"
        echo "  kubectl get nodes                         # Check cluster status"
        echo "  kubectl get pods -n argocd                # Check ArgoCD status"
        echo ""
        echo "Don't run away!"
      '';
    };

    formatter.${system} = pkgs.nixpkgs-fmt;
  };
}
# flake.nix
# Main flake configuration for the NERV Kubernetes Cluster Platform
# This file defines all our NixOS systems, development environment, and tools
# Run 'nix flake show' to see all available outputs

{
  description = "NERV - NixOS Kubernetes Platform";

  inputs = {
    # Use the current stable NixOS release (May 2025)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    # Define the system architecture we're targeting
    system = "x86_64-linux";

  in {
    # NixOS system configurations - each entry here becomes a deployable system
    nixosConfigurations = {
      # Misato - our primary node
      misato = nixpkgs.lib.nixosSystem {
        inherit system;
        # Modules are NixOS configuration files that get combined to build the system
        modules = [
          # Global config shared by all hosts
          ./hosts/common/global.nix
          # Host-specific config
          ./hosts/misato
        ];
      };
    };

    # Development environment for working on this flake
    # Enter with: nix develop
    devShells.${system}.default =
      let pkgs = nixpkgs.legacyPackages.${system};
      in pkgs.mkShell {
        # Tools available in the dev shell
        buildInputs = with pkgs; [
          neovim
          git
          nixos-rebuild
        ];

        # What gets printed when you enter the dev shell
        shellHook = ''
          echo "🤖 Welcome to NERV Command Centre"
          echo "Current configuration: misato"
          echo ""
          echo "Available commands:"
          echo "  • nix flake check              - validate flake syntax"
          echo "  • nix flake show               - show available outputs"
          echo "  • nixos-rebuild build --flake .#misato  - test build locally"
        '';
      };

    # Code formatter for .nix files - keeps code style consistent
    # Use with: nix fmt
    formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
  };
}
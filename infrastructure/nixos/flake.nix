# File: infrastructure/nixos/flake.nix
# Description: NixOS flake for NERV Kubernetes GitOps platform
# Learning Focus: Modular NixOS configuration with GitOps integration

{
  description = "NERV - NixOS Kubernetes GitOps Platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    nodes = [ "misato" ];

    mkNodeConfig = nodeName: {
      name = nodeName;
      value = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules/network.nix
          ./modules/base-system.nix
          ./modules/users.nix
          ./modules/node-roles.nix
          ./modules/services/flux.nix
          ./hosts/common/secrets.nix
          ./hosts/${nodeName}
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
        ];
      };
    };

  in
  {
    nixosConfigurations = builtins.listToAttrs (map mkNodeConfig nodes);

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        git
        nixos-rebuild
        nixos-anywhere
        age
        sops
        kubectl
        nixpkgs-fmt
      ];
    };

    formatter.${system} = pkgs.nixpkgs-fmt;
  };
}
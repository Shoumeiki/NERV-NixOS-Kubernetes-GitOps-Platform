# infrastructure/nixos/flake.nix
# NixOS flake for NERV platform deployment

{
  description = "NERV - NixOS Kubernetes Platform";

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

  outputs = { self, nixpkgs, disko, sops-nix, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    nodes = [ "misato" ];

    mkNodeConfig = nodeName: {
      name = nodeName;
      value = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/common/global.nix
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
      ];

      shellHook = ''
        echo "NERV Development Environment"
        echo "Commands:"
        echo "  nix flake check                      # Validate configurations"
        echo "  nix flake show                       # List available systems"  
        echo "  nixos-rebuild build --flake .#misato # Test build locally"
      '';
    };

    formatter.${system} = pkgs.nixpkgs-fmt;
  };
}
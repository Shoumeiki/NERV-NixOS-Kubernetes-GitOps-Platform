# infrastructure/nixos/flake.nix
#
# NERV Platform - NixOS Flake Configuration
#
# LEARNING OBJECTIVE: This flake demonstrates enterprise-grade NixOS configuration
# management using the modern flakes system. Key learning areas:
#
# 1. FLAKE ARCHITECTURE: Modern dependency management and system composition
# 2. MODULAR DESIGN: Reusable modules for scalable infrastructure management
# 3. DEPENDENCY PINNING: Reproducible builds through explicit input versioning
# 4. DEVELOPMENT WORKFLOW: Integrated development environment with tooling
#
# WHY FLAKES FOR INFRASTRUCTURE:
# - Reproducible builds eliminate "works on my machine" issues
# - Dependency locking ensures consistent deployments across environments
# - Modular architecture enables code reuse and maintainability
# - Development environments provide consistent tooling for team collaboration
#
# ENTERPRISE FLAKE PATTERN: This configuration establishes a foundation for
# multi-node infrastructure management with centralized dependency management,
# standardized tooling, and automated deployment workflows.

{
  description = ''
    NERV - NixOS Kubernetes GitOps Platform
    Enterprise-Grade Infrastructure as Code

    Production-ready Kubernetes infrastructure featuring:
    - Modular NixOS architecture for maintainability and scalability
    - Complete GitOps workflow with ArgoCD for declarative management
    - One-command deployment with nixos-anywhere automation
    - Enterprise secret management using SOPS-Nix encryption
    - Bare metal load balancing with MetalLB for cloud-like services
    - Distributed storage with Longhorn for persistent workloads
    - Security hardening and compliance-ready configurations
    - Comprehensive monitoring and observability integration
  '';

  # FLAKE INPUTS: Pinned dependencies for reproducible infrastructure
  inputs = {
    # NIXPKGS: Base NixOS packages and system definitions
    # Pinned to 25.05 stable channel for production reliability
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # DISKO: Declarative disk partitioning and filesystem management
    # Enables automated storage configuration during deployment
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";  # Avoid dependency conflicts
    };

    # SOPS-NIX: Encrypted secret management integrated with NixOS
    # Provides secure storage and deployment of sensitive configuration
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";  # Maintain consistency
    };
  };

  # FLAKE OUTPUTS: System configurations and development environment
  outputs = { self, nixpkgs, disko, sops-nix, ... }@inputs:
  let
    # TARGET ARCHITECTURE: Currently supports x86_64 Linux systems
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # CLUSTER NODE INVENTORY: Add new nodes to this list for automatic configuration
    # Each node gets its own directory under ./hosts/ with hardware-specific config
    nodes = [ "misato" ];  # Expand: [ "misato" "rei" "asuka" "shinji" ]

    # MODULAR CONFIGURATION BUILDER: Creates NixOS system for each node
    # This pattern enables consistent module composition across all cluster nodes
    mkNodeConfig = nodeName: {
      name = nodeName;
      value = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # FOUNDATION MODULES: Core system functionality and network configuration
          ./modules/network.nix      # Centralized IP allocation and GitOps repository config
          ./modules/base-system.nix  # System hardening, time sync, and Kubernetes prerequisites
          ./modules/users.nix        # SSH security hardening and administrative access
          ./modules/node-roles.nix   # Kubernetes node role management and workload scheduling

          # PLATFORM SERVICE MODULES: Complete Kubernetes infrastructure stack
          ./modules/services/argocd.nix           # GitOps controller with enterprise security
          ./modules/services/metallb.nix          # Bare metal load balancer for external access
          ./modules/services/longhorn.nix         # Distributed storage for persistent workloads
          ./modules/services/traefik.nix          # Ingress controller with TLS termination
          ./modules/services/cert-manager.nix     # Automated certificate management

          # NODE-SPECIFIC CONFIGURATIONS: Hardware profiles and secrets
          ./hosts/common/secrets.nix # SOPS encrypted credential management
          ./hosts/${nodeName}        # Hardware-specific configuration and service enablement

          # EXTERNAL MODULE INTEGRATION: Community modules for specialized functionality
          disko.nixosModules.disko   # Declarative disk partitioning and filesystem setup
          sops-nix.nixosModules.sops # Encrypted secret management with age/PGP
        ];
      };
    };

  in
  {
    # NIXOS SYSTEM CONFIGURATIONS: Generated configurations for all cluster nodes
    nixosConfigurations = builtins.listToAttrs (map mkNodeConfig nodes);

    # DEVELOPMENT ENVIRONMENT: Integrated tooling for infrastructure development
    # Provides consistent development experience across team members and CI/CD
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # CORE DEVELOPMENT TOOLS: Essential utilities for NixOS development
        git              # Version control for infrastructure code
        nixos-rebuild    # Local testing and validation of configurations

        # DEPLOYMENT AUTOMATION: Tools for production infrastructure deployment
        nixos-anywhere   # Remote NixOS installation and configuration

        # SECRET MANAGEMENT: Secure handling of sensitive configuration data
        age              # Modern encryption tool for SOPS
        sops             # Secrets OPerationS - encrypted configuration management

        # KUBERNETES ADMINISTRATION: Cluster management and debugging tools
        kubectl          # Kubernetes command-line interface

        # CODE QUALITY TOOLS: Maintaining consistent code formatting and standards
        nixpkgs-fmt      # Nix code formatter for consistent style
      ];

      # INTERACTIVE DEVELOPMENT SHELL: Provides contextual help and commands
      shellHook = ''
        echo "NERV Development Environment - Infrastructure as Code"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "CONFIGURATION MANAGEMENT:"
        echo "  nix flake check                           # Validate all configurations"
        echo "  nix flake show                            # List available systems"
        echo "  nixos-rebuild build --flake .#misato      # Test build configuration locally"
        echo "  nixpkgs-fmt **/*.nix                      # Format all Nix code"
        echo ""
        echo "DEPLOYMENT COMMANDS:"
        echo "  nixos-anywhere --flake .#misato root@IP   # Deploy complete infrastructure"
        echo "  nixos-anywhere --flake .#misato --build-on-remote root@IP  # Remote build"
        echo ""
        echo "SECRET MANAGEMENT:"
        echo "  sops secrets/secrets.yaml                 # Edit encrypted secrets"
        echo "  sops -d secrets/secrets.yaml              # Decrypt and view secrets"
        echo "  age-keygen -o ~/.config/sops/age/keys.txt # Generate new age key"
        echo ""
        echo "KUBERNETES OPERATIONS:"
        echo "  kubectl get nodes -o wide                 # Check cluster status"
        echo "  kubectl get pods -A                       # View all pods across namespaces"
        echo "  kubectl get applications -n argocd        # Check ArgoCD applications"
        echo "  kubectl logs -n argocd deployment/argocd-server  # ArgoCD logs"
        echo ""
        echo "MONITORING & DEBUGGING:"
        echo "  kubectl top nodes                         # Node resource usage"
        echo "  kubectl get events --sort-by=.metadata.creationTimestamp  # Recent events"
        echo "  kubectl describe node misato              # Detailed node information"
        echo ""
        echo "QUICK TIPS:"
        echo "  • Use 'kubectl config view' to check current cluster context"
        echo "  • Access ArgoCD UI at http://192.168.1.110"
        echo "  • Access Traefik dashboard at http://192.168.1.112:8080"
        echo "  • Access Longhorn UI at http://192.168.1.111"
        echo ""
        echo "Remember: All infrastructure changes should go through GitOps workflow!"
        echo ""
        echo "\"The fate of destruction is also the joy of rebirth.\" - Gendo Ikari"
      '';
    };

    # CODE FORMATTER: Consistent Nix code formatting across the project
    formatter.${system} = pkgs.nixpkgs-fmt;
  };
}
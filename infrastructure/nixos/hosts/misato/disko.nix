# hosts/misato/disko.nix
#
# Declarative Disk Configuration - Misato Node Storage Architecture
#
# LEARNING OBJECTIVE: This module demonstrates enterprise-grade storage
# configuration using Disko for declarative disk partitioning. Key learning areas:
#
# 1. DECLARATIVE STORAGE: Infrastructure-as-code approach to disk management
# 2. BTRFS OPTIMIZATION: Modern filesystem with compression and SSD optimization
# 3. STORAGE LAYOUT: Logical separation of system, user, and container data
# 4. PERFORMANCE TUNING: SSD-specific optimizations for longevity and speed
#
# WHY BTRFS FOR KUBERNETES NODES:
# - Copy-on-write enables efficient snapshots for system recovery
# - Compression reduces storage requirements and improves I/O performance
# - Subvolumes provide logical separation without partition overhead
# - Built-in integrity checking prevents silent data corruption
#
# ENTERPRISE STORAGE PATTERN: This configuration balances performance,
# reliability, and maintainability for production Kubernetes workloads
# while optimizing for mini PC hardware constraints.

{ pkgs, lib, ... }:

let
  # DYNAMIC DISK DETECTION: Automatically identify primary storage device
  # Enables deployment across different hardware configurations without manual adjustment
  primaryDisk = lib.removeSuffix "\n" (builtins.readFile (
    pkgs.runCommand "detect-primary-disk" {} ''
      ${pkgs.bash}/bin/bash ${../common/scripts/detect-primary-disk.sh} > $out
    ''
  ));
in

{
  # DISKO DECLARATIVE DISK CONFIGURATION: Complete storage layout definition
  disko.devices = {
    disk = {
      # PRIMARY STORAGE DEVICE: Main system disk with GPT partitioning
      main = {
        type = "disk";
        device = primaryDisk;  # Dynamically detected during deployment
        content = {
          type = "gpt";
          partitions = {
            # EFI SYSTEM PARTITION: UEFI boot loader and kernel storage
            ESP = {
              size = "512M";                 # Standard EFI partition size
              type = "EF00";                 # EFI system partition type
              content = {
                type = "filesystem";
                format = "vfat";             # Required for UEFI compatibility
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"               # Secure permissions (root read/write only)
                ];
              };
            };

            # ROOT PARTITION: Main filesystem with Btrfs and subvolume layout
            root = {
              size = "100%";                 # Use remaining disk space
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];        # Force creation, overwrite existing
                # BTRFS SUBVOLUME ARCHITECTURE: Logical separation for different data types
                subvolumes = {
                  # SYSTEM ROOT SUBVOLUME: Core operating system files
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "defaults"
                      "noatime"         # SSD optimization - disable access time updates
                      "compress=zstd:1" # Light compression for system files
                      "space_cache=v2"  # Improved free space tracking
                      "discard=async"   # Asynchronous SSD TRIM for performance
                    ];
                  };

                  # USER DATA SUBVOLUME: Home directories with higher compression
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:3" # Higher compression for user files
                      "space_cache=v2"
                      "discard=async"
                    ];
                  };

                  # NIX STORE SUBVOLUME: Package store optimized for performance
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"       # Disable CoW for better performance on package files
                    ];
                  };

                  # CONTAINER STORAGE SUBVOLUME: Container images and volumes
                  "@containers" = {
                    mountpoint = "/var/lib/containers";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                    ];
                  };

                  # LOG STORAGE SUBVOLUME: System and application logs
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"       # Disable CoW for better log write performance
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # ADDITIONAL FILESYSTEM MOUNTS: Special-purpose filesystems
  fileSystems = {
    # TEMPORARY FILESYSTEM: RAM-based temporary storage for performance and security
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=2G"      # 2GB limit appropriate for mini PC memory constraints
        "mode=1777"    # Standard temporary directory permissions (sticky bit)
      ];
    };
  };

  # SWAP CONFIGURATION: Disabled for SSD longevity and container workload optimization
  # Kubernetes workloads should be designed for resource limits rather than swap dependency
  swapDevices = [ ];
}
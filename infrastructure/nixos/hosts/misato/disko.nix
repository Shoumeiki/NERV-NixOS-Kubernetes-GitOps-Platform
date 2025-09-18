# File: infrastructure/nixos/hosts/misato/disko.nix
# Description: Declarative disk partitioning and Btrfs filesystem configuration
# Learning Focus: Disko disk management, Btrfs subvolumes, and filesystem optimization

{ pkgs, lib, ... }:

let
  # Dynamically detect the primary storage device at build time
  primaryDisk = lib.removeSuffix "\n" (builtins.readFile (
    pkgs.runCommand "detect-primary-disk" {} ''
      ${pkgs.bash}/bin/bash ${../common/scripts/detect-primary-disk.sh} > $out
    ''
  ));
in

{
  # Disko declarative disk configuration for automated partitioning
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = primaryDisk;  # Use detected primary disk
        content = {
          type = "gpt";        # GPT partition table for UEFI boot
          partitions = {
            # UEFI boot partition
            ESP = {
              size = "512M";
              type = "EF00";                    # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";               # FAT32 for UEFI compatibility
                mountpoint = "/boot";
                mountOptions = [ "defaults" "umask=0077" ];  # Secure boot directory
              };
            };

            # Main Btrfs partition with subvolumes
            root = {
              size = "100%";                    # Use remaining disk space
              content = {
                type = "btrfs";                 # Modern CoW filesystem
                extraArgs = [ "-f" ];            # Force creation
                subvolumes = {
                  # Root filesystem subvolume
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "defaults"
                      "noatime"          # Performance: disable access time updates
                      "compress=zstd:1"  # Fast compression for system files
                      "space_cache=v2"   # Improved free space caching
                      "discard=async"    # SSD optimization
                    ];
                  };

                  # User data subvolume with higher compression
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:3"  # Higher compression for user files
                      "space_cache=v2"
                      "discard=async"
                    ];
                  };

                  # Nix store subvolume optimized for many small files
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"        # Disable CoW for better performance
                    ];
                  };

                  # Container storage subvolume
                  "@containers" = {
                    mountpoint = "/var/lib/containers";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"  # Compress container images
                      "space_cache=v2"
                      "discard=async"
                    ];
                  };

                  # Log files subvolume
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"        # Disable CoW for frequent writes
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

  # Additional filesystem configurations
  fileSystems = {
    # Temporary files in RAM for performance
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=1777" ];  # 2GB RAM disk
    };
  };

  swapDevices = [ ];  # No swap - rely on available RAM
}
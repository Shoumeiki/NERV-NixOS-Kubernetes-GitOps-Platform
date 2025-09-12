# hosts/misato/disko.nix
# NERV Node - Misato Disk Configuration
#
# Declarative disk layout for Intel N150 Mini PC with NVMe storage
# Optimized for SSD longevity, performance, and container workloads
# Uses Btrfs with subvolumes for flexible snapshot and backup management

{ ... }:

{
  # Primary disk configuration
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            
            # UEFI boot partition
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"  # Secure boot partition permissions
                ];
              };
            };

            # Main system partition with Btrfs subvolumes
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  
                  # System root subvolume
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "defaults"
                      "noatime"         # Performance and SSD longevity
                      "compress=zstd:1" # Fast compression for system files
                      "space_cache=v2"  # Improved free space tracking
                      "discard=async"   # Async SSD TRIM support
                    ];
                  };

                  # User data subvolume
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

                  # Nix package store subvolume
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"       # Disable CoW for better performance
                    ];
                  };

                  # Container runtime storage
                  "@containers" = {
                    mountpoint = "/var/lib/containers";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1" # Light compression for container layers
                      "space_cache=v2"
                      "discard=async"
                    ];
                  };

                  # System logs subvolume
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"       # Disable CoW for log performance
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

  # Additional filesystem mounts
  fileSystems = {
    # Temporary files in RAM for performance
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=2G"      # Limit to 2GB for mini PC
        "mode=1777"    # Standard tmp permissions
      ];
    };
  };

  # No swap partition for SSD longevity
  # Consider zram-generator for memory compression if needed
  swapDevices = [ ];
}
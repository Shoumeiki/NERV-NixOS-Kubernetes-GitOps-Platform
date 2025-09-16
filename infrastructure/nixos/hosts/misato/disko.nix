# hosts/misato/disko.nix
# Misato disk configuration with Btrfs subvolumes

{ pkgs, lib, ... }:

let
  primaryDisk = lib.removeSuffix "\n" (builtins.readFile (
    pkgs.runCommand "detect-primary-disk" {} ''
      ${pkgs.bash}/bin/bash ${../common/scripts/detect-primary-disk.sh} > $out
    ''
  ));
in

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = primaryDisk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"  # Secure permissions
                ];
              };
            };

            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "defaults"
                      "noatime"         # SSD optimization
                      "compress=zstd:1" # Light compression
                      "space_cache=v2"
                      "discard=async"   # SSD TRIM
                    ];
                  };

                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:3" # Higher compression
                      "space_cache=v2"
                      "discard=async"
                    ];
                  };

                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"       # Better performance
                    ];
                  };

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

                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "defaults"
                      "noatime"
                      "compress=zstd:1"
                      "space_cache=v2"
                      "discard=async"
                      "nodatacow"       # Log performance
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

  fileSystems = {
    # Temporary files in RAM
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=2G"      # 2GB limit for mini PC
        "mode=1777"    # Standard permissions
      ];
    };
  };

  swapDevices = [ ];  # No swap for SSD longevity
}
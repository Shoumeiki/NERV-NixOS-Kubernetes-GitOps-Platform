#!/usr/bin/env bash
# infrastructure/nixos/hosts/common/scripts/detect-primary-disk.sh
#
# NERV Intelligent Storage Device Detection
#
# LEARNING OBJECTIVE: This script demonstrates automated storage device discovery
# for infrastructure-as-code deployments. Key learning areas:
#
# 1. STORAGE ENUMERATION: Systematic discovery of available storage devices
# 2. DEVICE CLASSIFICATION: Distinguishing between internal and removable storage
# 3. SAFETY MECHANISMS: Preventing accidental formatting of USB/removable drives
# 4. ENTERPRISE COMPATIBILITY: Support for both traditional SATA and modern NVMe
#
# WHY AUTOMATED DISK DETECTION:
# - Enables hardware-agnostic deployment configurations
# - Prevents manual device specification errors during deployment
# - Supports diverse hardware platforms (Mini PCs, servers, virtual machines)
# - Eliminates need for per-device disk configuration customization
#
# ENTERPRISE PATTERN: Infrastructure automation must adapt to hardware variations
# while maintaining safety guardrails to prevent data loss from incorrect device
# selection during automated deployments.

set -euo pipefail

# STORAGE CAPACITY ANALYSIS: Extract device size information from block layer
# This function provides standardized size reporting across different device types
get_disk_size() {
    local device="$1"

    # BLOCK DEVICE VALIDATION: Ensure target is a valid block device
    # Block devices are the standard interface for storage in Linux systems
    if [[ -b "$device" ]]; then
        # LSBLK SIZE EXTRACTION: Query block layer for device capacity in bytes
        # -b flag returns raw byte count, -n removes headers, SIZE column specified
        lsblk -bno SIZE "$device" 2>/dev/null || echo "0"
    else
        # INVALID DEVICE HANDLING: Return zero size for non-block devices
        echo "0"
    fi
}

# REMOVABLE DEVICE DETECTION: Identify USB drives and removable media
# Critical safety feature to prevent accidental formatting of external storage
is_removable() {
    local device="$1"

    # SYSFS REMOVABLE ATTRIBUTE: Query kernel's device classification
    # The removable attribute in /sys/block indicates if device is removable
    local sys_path="/sys/block/$(basename "$device")/removable"

    if [[ -f "$sys_path" ]]; then
        # REMOVABLE FLAG CHECK: Read kernel's removable device classification
        # "1" indicates removable device (USB drives, SD cards, etc.)
        [[ "$(cat "$sys_path")" == "1" ]]
    else
        # SYSFS UNAVAILABLE: Assume non-removable if sysfs data missing
        # Conservative approach - treat unknown devices as non-removable
        return 1
    fi
}

echo "NERV Storage Detection - Analyzing available storage devices..."

# SELECTION VARIABLES: Track best candidate device and its properties
primary_disk=""      # Path to selected primary storage device
max_size=0          # Size of largest suitable device found

echo "Phase 1: Analyzing persistent device identifiers..."

# PERSISTENT DEVICE ENUMERATION: Prefer stable device identifiers over dynamic names
# /dev/disk/by-id provides stable device names that persist across reboots
# This approach prevents deployment failures due to device name changes

# ENTERPRISE STORAGE ENUMERATION: Support modern storage technologies
for id_path in /dev/disk/by-id/ata-* /dev/disk/by-id/nvme-*; do
    # GLOB EXPANSION CHECK: Skip if no matching devices found
    [[ -e "$id_path" ]] || continue

    # PARTITION FILTERING: Skip partition entries, only consider whole devices
    # Partition entries end with -part[number] pattern
    [[ "$id_path" =~ -part[0-9]+$ ]] && continue

    # SYMLINK RESOLUTION: Convert by-id symlink to actual device path
    # by-id entries are symlinks to the actual device files in /dev
    actual_device=$(readlink -f "$id_path")

    echo "Evaluating: $(basename "$id_path")"

    # REMOVABLE DEVICE FILTERING: Skip USB drives and removable media
    # Critical safety measure to prevent accidental formatting
    if is_removable "$actual_device"; then
        echo "Skipped - Removable device (USB/external)"
        continue
    fi

    # DEVICE SIZE ANALYSIS: Query storage capacity for ranking
    size=$(get_disk_size "$actual_device")
    size_gb=$((size / 1000000000))  # Convert to GB for human readability

    echo "Size: ${size_gb}GB"

    # LARGEST DEVICE SELECTION: Choose device with maximum capacity
    # Assumes primary storage is typically the largest internal device
    if (( size > max_size )); then
        max_size=$size
        primary_disk="$id_path"
        echo "New primary candidate selected"
    else
        echo "Smaller than current candidate"
    fi
done

# FALLBACK ENUMERATION: Direct device path scanning for compatibility
# Some systems or virtualization platforms may not populate /dev/disk/by-id
if [[ -z "$primary_disk" ]]; then
    echo "Phase 2: Fallback to direct device enumeration..."

    # COMMON DEVICE PATTERNS: Standard Linux block device naming conventions
    # nvme0n1: NVMe SSD (modern systems)
    # sda/sdb: SATA/SCSI devices (traditional systems)
    # vda: Virtio block device (virtual machines)
    for device in /dev/nvme0n1 /dev/sda /dev/sdb /dev/vda; do
        # DEVICE EXISTENCE CHECK: Verify block device exists
        [[ -b "$device" ]] || continue

        echo "Evaluating: $(basename "$device")"

        # REMOVABLE SAFETY CHECK: Apply same safety filtering as by-id detection
        if is_removable "$device"; then
            echo "Skipped - Removable device"
            continue
        fi

        # SIZE ANALYSIS AND SELECTION: Same capacity-based ranking
        size=$(get_disk_size "$device")
        size_gb=$((size / 1000000000))

        echo "Size: ${size_gb}GB"

        if (( size > max_size )); then
            max_size=$size
            primary_disk="$device"
            echo "New primary candidate selected"
        else
            echo "Smaller than current candidate"
        fi
    done
fi

echo "Storage Device Selection Complete"

# SUCCESSFUL DETECTION: Report selected device with details
if [[ -n "$primary_disk" ]] && (( max_size > 0 )); then
    selected_size_gb=$((max_size / 1000000000))

    echo "Primary storage device selected:"
    echo "   • Device: $primary_disk"
    echo "   • Capacity: ${selected_size_gb}GB"
    echo "   • Type: $(if [[ "$primary_disk" =~ nvme ]]; then echo "NVMe SSD"; elif [[ "$primary_disk" =~ ata ]]; then echo "SATA"; else echo "Block Device"; fi)"

    # OUTPUT RESULT: Provide device path for disko configuration
    echo "$primary_disk"

else
    # DETECTION FAILURE HANDLING: Provide safe fallback with warning
    echo "WARNING: No suitable storage device detected"
    echo "   Using fallback device: /dev/sda"
    echo "   Manual verification recommended before deployment"

    # FALLBACK OUTPUT: Default to /dev/sda (most common device name)
    echo "/dev/sda"
fi

echo "Device path ready for disko configuration integration"
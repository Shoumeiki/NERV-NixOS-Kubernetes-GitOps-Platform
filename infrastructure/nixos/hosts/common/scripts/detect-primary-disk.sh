#!/usr/bin/env bash
# detect-primary-disk.sh
# Auto-detect primary storage device for disko

set -euo pipefail

# Function to get disk size in bytes
get_disk_size() {
    local device="$1"
    if [[ -b "$device" ]]; then
        lsblk -bno SIZE "$device" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to check if device is a USB/removable drive
is_removable() {
    local device="$1"
    local sys_path="/sys/block/$(basename "$device")/removable"
    if [[ -f "$sys_path" ]]; then
        [[ "$(cat "$sys_path")" == "1" ]]
    else
        return 1
    fi
}

# Find by-id devices (preferred)
primary_disk=""
max_size=0

# Check SATA/NVMe devices by ID
for id_path in /dev/disk/by-id/ata-* /dev/disk/by-id/nvme-*; do
    [[ -e "$id_path" ]] || continue

    # Skip partitions
    [[ "$id_path" =~ -part[0-9]+$ ]] && continue

    actual_device=$(readlink -f "$id_path")

    # Skip USB drives
    if is_removable "$actual_device"; then
        continue
    fi

    size=$(get_disk_size "$actual_device")

    # Select largest non-removable device
    if (( size > max_size )); then
        max_size=$size
        primary_disk="$id_path"
    fi
done

# Fallback to direct device paths
if [[ -z "$primary_disk" ]]; then
    for device in /dev/nvme0n1 /dev/sda /dev/sdb /dev/vda; do
        [[ -b "$device" ]] || continue

        if is_removable "$device"; then
            continue
        fi

        size=$(get_disk_size "$device")
        if (( size > max_size )); then
            max_size=$size
            primary_disk="$device"
        fi
    done
fi

# Output result
if [[ -n "$primary_disk" ]] && (( max_size > 0 )); then
    echo "$primary_disk"
else
    echo "/dev/sda"  # Fallback
fi
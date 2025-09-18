#!/usr/bin/env bash
# File: infrastructure/nixos/hosts/common/scripts/detect-primary-disk.sh
# Description: Intelligently detect the primary storage disk for NixOS installation
# Learning Focus: Hardware detection, device identification, and storage management

set -euo pipefail

get_disk_size() {
    local device="$1"
    if [[ -b "$device" ]]; then
        lsblk -bno SIZE "$device" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

is_removable() {
    local device="$1"
    local sys_path="/sys/block/$(basename "$device")/removable"
    
    if [[ -f "$sys_path" ]]; then
        [[ "$(cat "$sys_path")" == "1" ]]
    else
        return 1
    fi
}

primary_disk=""
max_size=0

for id_path in /dev/disk/by-id/ata-* /dev/disk/by-id/nvme-*; do
    [[ -e "$id_path" ]] || continue
    [[ "$id_path" =~ -part[0-9]+$ ]] && continue
    
    actual_device=$(readlink -f "$id_path")
    
    if is_removable "$actual_device"; then
        continue
    fi
    
    size=$(get_disk_size "$actual_device")
    
    if (( size > max_size )); then
        max_size=$size
        primary_disk="$id_path"
    fi
done

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

if [[ -n "$primary_disk" ]] && (( max_size > 0 )); then
    echo "$primary_disk"
else
    echo "/dev/sda"
fi
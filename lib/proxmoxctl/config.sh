#!/bin/bash

cmd_set_memory() {
    local target="${2:?Usage: proxmoxctl set-memory <VMID|name> <MB> [--no-snapshot]}"
    local memory="${3:?Usage: proxmoxctl set-memory <VMID|name> <MB> [--no-snapshot]}"
    local flag="${4:-}"

    validate_integer \
        "$memory" \
        "Memory" \
        128

    if [[ -n "$flag" && "$flag" != "--no-snapshot" ]]; then
        echo "Unknown option: $flag" >&2
        return 1
    fi

    guest_info "$target"

    if [[ "$flag" != "--no-snapshot" ]]; then
        snapshot_before_change \
            "$VMID" \
            memory
    fi

    echo \
        "Setting memory for ${NAME:-$VMID} ($VMID) to ${memory} MB..."

    api_put \
        "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/config" \
        --data-urlencode "memory=$memory" \
        >/dev/null

    echo \
        "Memory configuration updated."
}

cmd_set_cores() {
    local target="${2:?Usage: proxmoxctl set-cores <VMID|name> <count> [--no-snapshot]}"
    local cores="${3:?Usage: proxmoxctl set-cores <VMID|name> <count> [--no-snapshot]}"
    local flag="${4:-}"

    validate_integer \
        "$cores" \
        "Core count" \
        1

    if [[ -n "$flag" && "$flag" != "--no-snapshot" ]]; then
        echo "Unknown option: $flag" >&2
        return 1
    fi

    guest_info "$target"

    if [[ "$flag" != "--no-snapshot" ]]; then
        snapshot_before_change \
            "$VMID" \
            cores
    fi

    echo \
        "Setting cores for ${NAME:-$VMID} ($VMID) to $cores..."

    api_put \
        "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/config" \
        --data-urlencode "cores=$cores" \
        >/dev/null

    echo \
        "Core configuration updated."
}

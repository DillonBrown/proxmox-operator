#!/bin/bash

cmd_backup() {
    local target="${2:?Usage: proxmoxctl backup <VMID|name> [storage]}"
    local storage="${3:-local}"

    local response
    local upid

    guest_info "$target"

    echo \
        "Starting backup of ${NAME:-$VMID} ($VMID) to '$storage'..."

    response=$(
        api_post \
            "$API/nodes/${PROXMOX_NODE}/vzdump" \
            --data-urlencode "vmid=$VMID" \
            --data-urlencode "storage=$storage" \
            --data-urlencode "mode=snapshot" \
            --data-urlencode "compress=zstd"
    )

    upid=$(extract_upid <<< "$response")

    echo \
        "Backup task submitted. Waiting for completion..."

    wait_for_task \
        "$upid" \
        7200

    echo \
        "Backup of ${NAME:-$VMID} ($VMID) completed successfully."
}

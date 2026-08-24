#!/bin/bash

cmd_snapshots() {
    local target="${2:?Usage: proxmoxctl snapshots <VMID|name>}"

    guest_info "$target"

    api_get \
        "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/snapshot" |
        python3 -c '
import json
import sys

snapshots = json.load(sys.stdin).get("data", [])

print(
    "{:<28} {:<20} {}".format(
        "SNAPSHOT",
        "PARENT",
        "DESCRIPTION"
    )
)

for snapshot in snapshots:

    if snapshot.get("name") == "current":
        continue

    print(
        "{:<28} {:<20} {}".format(
            snapshot.get("name", ""),
            snapshot.get("parent", "") or "",
            snapshot.get("description", "") or ""
        )
    )
'
}

create_snapshot() {
    local target="$1"
    local snapname="$2"
    local description="${3:-}"

    local response
    local upid

    guest_info "$target"

    if [[ ! "$snapname" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        echo \
            "Snapshot name may contain only letters, numbers, dots, underscores, and hyphens." \
            >&2
        return 1
    fi

    echo \
        "Creating snapshot '$snapname' for ${NAME:-$VMID} ($VMID)..."

    if [[ -n "$description" ]]; then

        response=$(
            api_post \
                "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/snapshot" \
                --data-urlencode "snapname=$snapname" \
                --data-urlencode "description=$description"
        )

    else

        response=$(
            api_post \
                "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/snapshot" \
                --data-urlencode "snapname=$snapname"
        )

    fi

    upid=$(extract_upid <<< "$response")

    wait_for_task \
        "$upid" \
        1800

    echo \
        "Snapshot '$snapname' created successfully."
}

cmd_snapshot() {
    local target="${2:?Usage: proxmoxctl snapshot <VMID|name> <snapshot-name> [description]}"
    local snapname="${3:?Usage: proxmoxctl snapshot <VMID|name> <snapshot-name> [description]}"
    local description="${4:-}"

    create_snapshot \
        "$target" \
        "$snapname" \
        "$description"
}

snapshot_before_change() {
    local target="$1"
    local operation="$2"

    local snapname

    snapname="auto-${operation}-$(timestamp_name)"

    create_snapshot \
        "$target" \
        "$snapname" \
        "Automatic snapshot before $operation"
}

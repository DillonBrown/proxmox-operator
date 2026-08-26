#!/bin/bash

cmd_list() {
    local format="${2:-}"
    local module_dir

    module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -n "$format" && "$format" != "--json" ]] || (( $# > 2 )); then
        echo "Usage: proxmoxctl list [--json]" >&2
        return 1
    fi

    if [[ "$format" == "--json" ]]; then
        resources | python3 "$module_dir/guest_list.py"
        return
    fi

    resources | python3 -c '
import json
import sys

guests = json.load(sys.stdin).get("data", [])

guests.sort(
    key=lambda guest: guest.get("vmid", 0)
)

print(
    "{:<8} {:<8} {:<10} {}".format(
        "VMID",
        "TYPE",
        "STATUS",
        "NAME"
    )
)

for guest in guests:
    print(
        "{:<8} {:<8} {:<10} {}".format(
            guest.get("vmid", ""),
            guest.get("type", ""),
            guest.get("status", ""),
            guest.get("name", "")
        )
    )
'
}

cmd_status() {
    local target="${2:?Usage: proxmoxctl status <VMID|name>}"

    guest_info "$target"

    get_status_json \
        "$TYPE" \
        "$VMID" |
        python3 -m json.tool
}

cmd_config() {
    local target="${2:?Usage: proxmoxctl config <VMID|name>}"

    guest_info "$target"

    get_config_json \
        "$TYPE" \
        "$VMID" |
        python3 -m json.tool
}

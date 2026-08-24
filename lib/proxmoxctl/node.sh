#!/bin/bash

cmd_node_status() {
    local format="${2:-}"
    local module_dir

    module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

    if [[ "$format" != "--json" || $# -ne 2 ]]; then
        echo \
            "Usage: proxmoxctl node-status --json" \
            >&2
        return 1
    fi

    get_node_status_json | python3 "$module_dir/node_status.py" "$PROXMOX_NODE"
}

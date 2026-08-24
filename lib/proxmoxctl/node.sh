#!/bin/bash

cmd_node_status() {
    local format="${2:-}"

    if [[ "$format" != "--json" || $# -ne 2 ]]; then
        echo \
            "Usage: proxmoxctl node-status --json" \
            >&2
        return 1
    fi

    get_node_status_json | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
data = payload.get("data", {})

def integer(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default

def number(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

def load_average(values):
    if not isinstance(values, (list, tuple)):
        values = []

    return {
        "one_minute": number(values[0]) if len(values) > 0 else None,
        "five_minutes": number(values[1]) if len(values) > 1 else None,
        "fifteen_minutes": number(values[2]) if len(values) > 2 else None,
    }

memory = data.get("memory", {})

if not isinstance(memory, dict):
    memory = {}

# Proxmox node status uses memory.{total,used,free} on current releases.
# Fall back to the older maxmem/mem response shape when necessary.
total = integer(memory.get("total", data.get("maxmem")))
used = integer(memory.get("used", data.get("mem")))
free = integer(memory.get("free"), max(total - used, 0))

result = {
    "node": {
        "name": sys.argv[1],
        "logical_cpu_cores": integer(data.get("cpuinfo", {}).get("cpus")),
    },
    "cpu": {
        "utilization": number(data.get("cpu")),
    },
    "load_average": load_average(data.get("loadavg")),
    "memory": {
        "total_bytes": total,
        "used_bytes": used,
        "free_bytes": free,
    },
}

json.dump(result, sys.stdout, indent=2, sort_keys=True)
print()
' "$PROXMOX_NODE"
}

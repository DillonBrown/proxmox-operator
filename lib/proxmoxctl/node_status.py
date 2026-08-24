#!/usr/bin/env python3
"""Format a Proxmox node-status API response as the proxmoxctl JSON contract."""

import json
import sys


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


def node_status(payload, node_name):
    """Return the stable capacity snapshot for a Proxmox API payload."""
    data = payload.get("data", {})
    if not isinstance(data, dict):
        data = {}

    memory = data.get("memory", {})
    if not isinstance(memory, dict):
        memory = {}

    cpuinfo = data.get("cpuinfo", {})
    if not isinstance(cpuinfo, dict):
        cpuinfo = {}

    # Proxmox node status uses memory.{total,used,free} on current releases.
    # Fall back to the older maxmem/mem response shape when necessary.
    total = integer(memory.get("total", data.get("maxmem")))
    used = integer(memory.get("used", data.get("mem")))
    free = integer(memory.get("free"), max(total - used, 0))

    return {
        "node": {
            "name": node_name,
            "logical_cpu_cores": integer(cpuinfo.get("cpus")),
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


def main():
    if len(sys.argv) != 2:
        print("Usage: node_status.py <node-name>", file=sys.stderr)
        return 2

    payload = json.load(sys.stdin)
    json.dump(node_status(payload, sys.argv[1]), sys.stdout, indent=2, sort_keys=True)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())

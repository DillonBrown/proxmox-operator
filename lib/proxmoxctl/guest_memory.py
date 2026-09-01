#!/usr/bin/env python3
"""Normalize Proxmox guest configuration and status as a safe memory baseline."""

import json
import pathlib
import sys


MEBIBYTE = 1024 * 1024


def integer(value):
    """Return non-negative integral values without inventing a metric."""
    if isinstance(value, bool):
        return None
    try:
        result = int(value)
    except (TypeError, ValueError):
        return None
    return result if result >= 0 else None


def megabytes_to_bytes(value):
    value = integer(value)
    return None if value is None else value * MEBIBYTE


def read_payload(path):
    with pathlib.Path(path).open(encoding="utf-8") as stream:
        payload = json.load(stream)
    data = payload.get("data") if isinstance(payload, dict) else None
    return data if isinstance(data, dict) else {}


def signal(value):
    """Preserve only numeric Proxmox signals; absent or malformed is null."""
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return value if value >= 0 else None
    return None


def unavailable(reason):
    return {"available": False, "reason": reason}


def normalize(guest_type, vmid, name, config, status):
    balloon = status.get("ballooninfo")
    balloon = balloon if isinstance(balloon, dict) else {}

    return {
        "guest": {
            "vmid": integer(vmid),
            "name": name,
            "type": guest_type,
            "status": status.get("status") if isinstance(status.get("status"), str) else None,
        },
        "memory": {
            "configured_limit_bytes": megabytes_to_bytes(config.get("memory")),
            "current_bytes": integer(status.get("mem")),
            "resident_bytes": integer(status.get("memhost")),
        },
        "signals": {
            "balloon": {
                "actual_bytes": integer(balloon.get("actual")),
                "total_bytes": integer(balloon.get("total_mem")),
                "free_bytes": integer(balloon.get("free_mem")),
                "maximum_bytes": integer(balloon.get("max_mem")),
            },
            "pressure": {
                "memory_some": signal(status.get("pressurememorysome")),
                "memory_full": signal(status.get("pressurememoryfull")),
            },
            "swap": {
                "balloon_in_bytes": integer(balloon.get("mem_swapped_in")),
                "balloon_out_bytes": integer(balloon.get("mem_swapped_out")),
            },
        },
        "capabilities": {
            "guest_meminfo": unavailable("not available from hypervisor status/config"),
            "process_memory": unavailable("not available from hypervisor status/config"),
            "container_memory": unavailable("not available from hypervisor status/config"),
            "oom_events": unavailable("not available from hypervisor status/config"),
        },
    }


def main():
    if len(sys.argv) != 6:
        raise SystemExit("Usage: guest_memory.py <type> <vmid> <name> <config-json> <status-json>")

    guest_type, vmid, name, config_path, status_path = sys.argv[1:]
    if guest_type not in {"qemu", "lxc"}:
        raise SystemExit("Unsupported guest type")

    print(json.dumps(normalize(guest_type, vmid, name, read_payload(config_path), read_payload(status_path)), sort_keys=True))


if __name__ == "__main__":
    main()

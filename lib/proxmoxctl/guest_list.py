#!/usr/bin/env python3
"""Format Proxmox guest inventory as the proxmoxctl list JSON contract."""

import json
import sys


def integer(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def text(value):
    return value if isinstance(value, str) else ""


def guest_list(payload):
    """Return a stable, VMID-sorted guest inventory from an API payload."""
    guests = payload.get("data", [])
    if not isinstance(guests, list):
        guests = []

    result = []
    for guest in guests:
        if not isinstance(guest, dict):
            continue

        result.append(
            {
                "vmid": integer(guest.get("vmid")),
                "type": text(guest.get("type")),
                "status": text(guest.get("status")),
                "name": text(guest.get("name")),
                "node": text(guest.get("node")),
            }
        )

    result.sort(key=lambda guest: (guest["vmid"] is None, guest["vmid"] or 0))
    return {"guests": result}


def main():
    json.dump(guest_list(json.load(sys.stdin)), sys.stdout, indent=2, sort_keys=True)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())

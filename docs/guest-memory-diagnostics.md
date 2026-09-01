# Guest-memory diagnostics design

## Architecture and command

Add one inspection-only command:

```text
proxmoxctl guest-memory <VMID|name>
```

The first implementation is a generic, strictly read-only hypervisor-level
baseline for both QEMU VMs and LXCs. It combines the existing configuration
and current-status reads into a bounded, stable JSON snapshot. It is intended
for diagnosis, not monitoring or remediation. The command accepts exactly one
target; it has no flags for guest commands, paths, filters, or output
selection.

This baseline reports configured/current/resident memory plus only the
balloon, pressure, and swap signals that Proxmox already supplies. It marks
guest `/proc`, process, container, and OOM evidence unavailable; it must never
guess those values or add guest access merely to fill them.

## JSON contract

All byte quantities are integers or `null`. Missing Proxmox signals are `null`;
in-guest capabilities use an explicit unavailable record. The command must
not emit a raw Proxmox response.

```json
{
  "guest": {"vmid": 100, "name": "homeassistant", "type": "qemu", "status": "running"},
  "memory": {
    "configured_limit_bytes": 6442450944,
    "current_bytes": 0,
    "resident_bytes": null
  },
  "signals": {
    "balloon": {"actual_bytes": null, "total_bytes": null, "free_bytes": null, "maximum_bytes": null},
    "pressure": {"memory_some": null, "memory_full": null},
    "swap": {"balloon_in_bytes": null, "balloon_out_bytes": null}
  },
  "capabilities": {
    "guest_meminfo": {"available": false, "reason": "not available from hypervisor status/config"},
    "process_memory": {"available": false, "reason": "not available from hypervisor status/config"},
    "container_memory": {"available": false, "reason": "not available from hypervisor status/config"},
    "oom_events": {"available": false, "reason": "not available from hypervisor status/config"}
  }
}
```

The baseline emits `null` signal values when Proxmox does not provide them and
uses explicit unavailable capability records for all in-guest detail. It does
not emit fabricated process, container, or OOM arrays.

## Deferred future enhancements (not part of this change)

The baseline requires no guest agent and never invokes guest execution. API
credentials remain in the existing protected local configuration; the command
must never print token material, authorization headers, endpoint URLs, or
unfiltered API responses.

Future detail adapters are opt-in extensions, never fallbacks for the
hypervisor baseline. They are explicitly deferred from this change.

- A QEMU detail adapter would require QEMU guest agent plus a separately
  provisioned, root-owned fixed guest collector at an immutable path. It would
  accept no caller-controlled arguments, read only approved memory sources,
  and emit the validated guest-memory JSON schema.
- An LXC detail adapter would require an equivalent constrained, read-only
  telemetry endpoint. It must not use host shell access, `pct exec`, or an
  arbitrary container command.

Each adapter requires separate security review, least-privilege permission
grant, provisioning, and tests before it can populate currently unavailable
fields.

## Safety and failure behavior

- Resolve the target through live inventory and reject non-QEMU/non-LXC
  guests. Stopped guests return their known configuration with unavailable
  runtime metrics.
- Normalize and validate only configuration/status fields supplied by Proxmox.
- Treat missing status/config metrics as `null`, and missing in-guest
  capabilities as explicitly unavailable. Do not retry through host shell,
  raw API calls, SSH, Home Assistant APIs, or a broader permission scope.
- Do not change VM configuration, guest state, add-ons, containers, logs,
  swap, caches, or credentials. Do not clear cache or run remediation.

## Tests

Add fixture-driven tests for QEMU and LXC status/config normalization, command
dispatch, exact-one-selector enforcement, missing metrics, and sanitized
capabilities. Tests must prove that extra arguments, arbitrary paths,
arbitrary guest commands, and raw credential/API output are rejected.

## Staged rollout

1. Land the QEMU/LXC hypervisor baseline, parser contract, and unit tests.
2. Validate it against non-production QEMU and LXC fixtures and live read-only
   status data.
3. Independently review and provision one fixed QEMU adapter helper on a
   non-production guest, without changing baseline behavior.
4. Design and review an equivalent LXC telemetry adapter separately.
5. Opt in production guests individually; any collection or remediation
   expansion requires a separate design and review.

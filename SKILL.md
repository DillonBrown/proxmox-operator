---
name: proxmox
description: Manage and inspect the local Proxmox VE environment using the restricted proxmoxctl helper.
---

# Proxmox Management

Use the `exec` tool with `/usr/local/bin/proxmoxctl`. `/usr/local/bin/proxctl`
is an equivalent short alias.

Do not construct raw Proxmox API requests when `proxmoxctl` can perform the task.

## Available commands

### Inventory and inspection

- `/usr/local/bin/proxmoxctl list [--json]`
- `/usr/local/bin/proxmoxctl status <VMID|name>`
- `/usr/local/bin/proxmoxctl config <VMID|name>`
- `/usr/local/bin/proxmoxctl guest-memory <VMID|name>`
- `/usr/local/bin/proxmoxctl node-status --json`

### Power

- `/usr/local/bin/proxmoxctl start <VMID|name>`
- `/usr/local/bin/proxmoxctl shutdown <VMID|name>`
- `/usr/local/bin/proxmoxctl reboot <VMID|name>`
- `/usr/local/bin/proxmoxctl restart <VMID|name>`
- `/usr/local/bin/proxmoxctl wait <VMID|name> <running|stopped>`

### Snapshots

- `/usr/local/bin/proxmoxctl snapshots <VMID|name>`
- `/usr/local/bin/proxmoxctl snapshot <VMID|name> <snapshot-name> [description]`

### Backups

- `/usr/local/bin/proxmoxctl backup <VMID|name> [storage]`

### Guest configuration

- `/usr/local/bin/proxmoxctl set-memory <VMID|name> <MB>`
- `/usr/local/bin/proxmoxctl set-cores <VMID|name> <count>`

## Node capacity

For host CPU/RAM headroom questions, use:
`/usr/local/bin/proxmoxctl node-status --json`

Report only the values it returns. Treat `free_bytes` as immediately free memory; do not count cached or otherwise unreported memory as guaranteed capacity.

For a QEMU VM or LXC's hypervisor-level memory baseline, use:
`/usr/local/bin/proxmoxctl guest-memory <VMID|name>`.
It does not execute commands in the guest; fields that require in-guest
access are explicitly unavailable.

## Guest resolution

Use live Proxmox inventory to resolve guest names.

Never guess a VMID.

If the user names a guest, prefer using the guest name directly with `proxmoxctl`.

## Safety policy

Read-only operations may be performed immediately.

For configuration changes that can affect guest operation, preserve a rollback point first.

Examples include:

- CPU changes
- memory changes
- disk configuration changes
- network configuration changes
- guest option changes
- application or OS upgrades when a Proxmox snapshot is appropriate

For these changes:

1. Inspect the current guest status/config when useful.
2. Create a snapshot before the change unless:
   - `proxmoxctl` already performs an automatic snapshot for that command, or
   - the user explicitly asks not to create one.
3. Perform the requested change.
4. Verify the guest remains or returns to the expected running state.
5. Report the result and the snapshot name.

Do not create duplicate snapshots when the invoked `proxmoxctl` command already snapshots automatically.

For high-impact maintenance or when the user specifically asks for a durable backup, prefer a full backup in addition to or instead of a snapshot.

## Snapshot vs backup

Use a snapshot when:

- making a reversible guest configuration change
- restarting after an application/configuration change
- preparing for a relatively quick rollback

Use a full backup when:

- the user explicitly asks for a backup
- performing major maintenance
- preparing for an upgrade with meaningful data-loss risk
- a snapshot alone would not provide sufficient protection

Snapshots are not a substitute for independent backups.

## Power operations

- Start operations may be performed when clearly requested.
- Shutdown/restart/reboot must target exactly the requested guest.
- After a restart, verify the guest actually came back.
- Do not claim success merely because Proxmox accepted the task.

## Destructive actions

Do not delete:

- VMs
- LXCs
- disks
- snapshots
- backups

unless explicit support for that action has been deliberately added to `proxmoxctl` and the user clearly requests it.

Do not attempt to bypass missing permissions.

## Prohibited host administration

Do not modify:

- Proxmox users or API tokens
- ACLs or roles
- host networking
- storage definitions
- cluster configuration
- the Proxmox host operating system

Do not attempt host root access.

## Credentials

Never read, display, copy, or modify:

`/etc/openclaw/proxmox.env`

Never expose the Proxmox API token.

## Failures

If an operation fails:

- report the actual error
- do not broaden permissions yourself
- do not attempt unrelated administrative commands
- preserve any rollback point that was created

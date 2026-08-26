# proxmoxctl

`proxmoxctl` is a small, restricted command-line toolkit for operating a
configured Proxmox VE environment. It is designed for direct human use,
shell scripts, and AI agents that need a deliberately narrow operational
surface rather than unrestricted hypervisor access.

The tool talks to the Proxmox VE API using its own local configuration. It
does not require, expose, or grant host shell access to the Proxmox node.

## Installation

Clone or unpack this repository, then install the launcher and modules under
the desired prefix:

```bash
./install.sh
```

The default prefix is `/usr/local`, which installs the canonical launcher at
`/usr/local/bin/proxmoxctl`, its short alias at `/usr/local/bin/proxctl`, and
modules under `/usr/local/lib/proxmoxctl`.
Choose another absolute prefix with `--prefix`:

```bash
./install.sh --prefix /opt/proxmoxctl
```

The installer refuses to overwrite an existing launcher or module. Use
`--force` only when you intentionally want to replace an existing install:

```bash
./install.sh --prefix /usr/local --force
```

It installs no credentials and creates no configuration files.

## Configuration and least privilege

Install the launcher and its `lib/proxmoxctl` modules together. The launcher
loads a protected local environment file whose location is configured by the
shared module. That file must provide the Proxmox API endpoint, target node,
token identity, and token secret. Keep it readable only by the account that
runs `proxmoxctl`; do not pass token material on the command line, commit it,
or print it in logs.

Start from [`examples/proxmox.env.example`](examples/proxmox.env.example).
It contains placeholders only and uses the exact names expected by the CLI:

```text
PROXMOX_HOST
PROXMOX_NODE
PROXMOX_TOKEN_ID
PROXMOX_TOKEN_SECRET
```

Copy it only to the protected location configured by
`lib/proxmoxctl/common.sh`, replace the placeholders locally, and restrict
file permissions. The installer deliberately does not perform that step.

Create a dedicated API token with only the permissions required for the
commands you intend to use. For read-only inventory and node status, grant
read/audit access only to the intended node and guests. Commands that change
guest state or configuration require their corresponding, narrowly scoped
Proxmox permissions. The CLI makes no attempt to elevate or bypass missing
permissions.

### API token setup

Follow the Proxmox [API token documentation](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#pveum_tokens)
to create a dedicated, non-root service user and a clearly named token for
this integration. Store the token secret when Proxmox displays it: it is shown
only once. Keep privilege separation enabled and assign the token only the
ACLs required for the commands you enable, scoped to the intended node,
guests, and backup storage; do not grant broad administrator, host, user, or
ACL-management privileges.

Protect the environment file with mode `0600`, readable only by the account
that runs the CLI. Rotate tokens on a defined schedule and revoke them
immediately when the integration is retired or suspected compromised. `proxmoxctl` verifies the
Proxmox TLS certificate. Install the appropriate CA certificate in the system
trust store, or set the optional `PROXMOX_CA_FILE` to a readable PEM CA bundle
for a private CA; do not disable certificate verification.

An Agent can invoke this CLI as an optional integration, but `proxmoxctl`
remains a standalone tool with the same safety boundaries in every caller.

## Commands

`proxmoxctl` is the canonical command. `proxctl` is an installed short alias
with the same commands and behavior.

### Read-only inspection

```text
proxmoxctl list [--json]
proxmoxctl status <VMID|name>
proxmoxctl config <VMID|name>
proxmoxctl node-status --json
```

`list` discovers the live guest inventory; `list --json` returns a stable,
machine-readable `guests` array sorted by VMID. `status` and `config` accept a
VMID or an exact guest name. `node-status --json` returns a stable,
machine-readable capacity snapshot containing node identity, logical CPU
core count, current CPU utilization, load averages when supplied by Proxmox,
and total/used/free memory in bytes.

Example capacity query:

```bash
proxmoxctl node-status --json
```

### Guest operations

```text
proxmoxctl start <VMID|name> [timeout]
proxmoxctl shutdown <VMID|name> [timeout]
proxmoxctl reboot <VMID|name>
proxmoxctl restart <VMID|name> [timeout]
proxmoxctl wait <VMID|name> <running|stopped> [timeout]

proxmoxctl snapshots <VMID|name>
proxmoxctl snapshot <VMID|name> <snapshot-name> [description]
proxmoxctl backup <VMID|name> [storage]

proxmoxctl set-memory <VMID|name> <MB> [--no-snapshot]
proxmoxctl set-cores <VMID|name> <count> [--no-snapshot]
```

## Examples

List guests before targeting one by name:

```bash
proxmoxctl list
proxmoxctl status homeassistant
```

Capture host capacity metrics in a script:

```bash
proxmoxctl node-status --json
```

Inspect the configured CPU and memory limits for a guest:

```bash
proxmoxctl config 101
```

## Module layout

```text
bin/proxmoxctl                 Command launcher and command dispatch
lib/proxmoxctl/common.sh       Protected configuration loading and API helpers
lib/proxmoxctl/guest.sh        Guest inventory, status, and configuration reads
lib/proxmoxctl/guest_list.py   Guest inventory JSON formatter
lib/proxmoxctl/node.sh         Read-only node capacity JSON
lib/proxmoxctl/node_status.py  Node-status JSON formatter
lib/proxmoxctl/power.sh        Guest power and wait operations
lib/proxmoxctl/snapshot.sh     Snapshot listing and creation
lib/proxmoxctl/backup.sh       Backup submission and completion waiting
lib/proxmoxctl/config.sh       Guest CPU and memory limit changes
```

## Safety model

- Prefer `list` to resolve a guest before taking an action; never guess a
  VMID.
- Read-only commands can be used for inventory and capacity assessment without
  modifying guest state.
- Power, snapshot, backup, and guest resource commands act only on the named
  guest through the Proxmox API; they do not run commands on the Proxmox host.
- Use snapshots or independent backups according to your change-control and
  recovery requirements. A snapshot is not a substitute for a backup.
- Treat output as operational data. The tool intentionally keeps API
  credentials out of output and command arguments.

## Optional agent integration

An Agent can call the installed CLI as one consumer among many. Keep the same
dedicated token, least-privilege permissions, and protected configuration
file regardless of whether the caller is a person, a script, or an agent.

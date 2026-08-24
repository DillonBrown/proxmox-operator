# OpenClaw Proxmox Operator

`proxmoxctl` provides a restricted command-line interface for the configured
Proxmox environment.

## Node capacity status

Use the read-only node status command for host capacity metrics:

```bash
proxmoxctl node-status --json
```

It returns the configured node name, logical CPU core count, current CPU
utilization (as a fraction from the Proxmox API), load averages when supplied
by the API, and total/used/free memory in bytes.

#!/usr/bin/env python3
"""Regression tests for the node-status formatter and shell wrapper."""

import json
import pathlib
import subprocess
import unittest


REPOSITORY = pathlib.Path(__file__).resolve().parents[1]
FORMATTER = REPOSITORY / "lib/proxmoxctl/node_status.py"
WRAPPER = REPOSITORY / "lib/proxmoxctl/node.sh"


class NodeStatusTest(unittest.TestCase):
    def run_formatter(self, payload, node_name="pve-a"):
        result = subprocess.run(
            ["python3", str(FORMATTER), node_name],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            check=True,
        )
        return json.loads(result.stdout)

    def test_current_proxmox_memory_shape(self):
        result = self.run_formatter(
            {
                "data": {
                    "cpu": "0.25",
                    "cpuinfo": {"cpus": "8"},
                    "loadavg": ["1.0", 2, "bad"],
                    "memory": {"total": "1000", "used": "300", "free": "700"},
                }
            }
        )

        self.assertEqual(
            result,
            {
                "node": {"name": "pve-a", "logical_cpu_cores": 8},
                "cpu": {"utilization": 0.25},
                "load_average": {
                    "one_minute": 1.0,
                    "five_minutes": 2.0,
                    "fifteen_minutes": None,
                },
                "memory": {"total_bytes": 1000, "used_bytes": 300, "free_bytes": 700},
            },
        )

    def test_legacy_memory_shape_and_shell_wrapper(self):
        payload = {"data": {"maxmem": 1000, "mem": 400, "cpuinfo": {"cpus": 4}}}
        command = (
            "payload=$1; PROXMOX_NODE=pve-b; "
            "get_node_status_json() { printf '%s' \"$payload\"; }; "
            "source \"$2\"; cmd_node_status node-status --json"
        )
        result = subprocess.run(
            ["bash", "-c", command, "bash", json.dumps(payload), str(WRAPPER)],
            text=True,
            capture_output=True,
            check=True,
        )

        self.assertEqual(
            json.loads(result.stdout)["memory"],
            {"total_bytes": 1000, "used_bytes": 400, "free_bytes": 600},
        )
        self.assertEqual(json.loads(result.stdout)["node"]["name"], "pve-b")


if __name__ == "__main__":
    unittest.main()

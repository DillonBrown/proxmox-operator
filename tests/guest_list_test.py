#!/usr/bin/env python3
"""Regression tests for the stable guest-list JSON formatter and wrapper."""

import json
import pathlib
import subprocess
import unittest


REPOSITORY = pathlib.Path(__file__).resolve().parents[1]
FORMATTER = REPOSITORY / "lib/proxmoxctl/guest_list.py"
WRAPPER = REPOSITORY / "lib/proxmoxctl/guest.sh"


class GuestListTest(unittest.TestCase):
    def test_formatter_normalizes_and_sorts_inventory(self):
        payload = {
            "data": [
                {"vmid": "200", "type": "qemu", "status": "running", "name": "beta"},
                {"vmid": 101, "type": "lxc", "status": "stopped", "name": "alpha", "node": "pve-a"},
                {"vmid": "bad", "type": None, "status": 1, "name": None},
                "not-a-guest",
            ]
        }
        result = subprocess.run(
            ["python3", str(FORMATTER)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            check=True,
        )

        self.assertEqual(
            json.loads(result.stdout),
            {
                "guests": [
                    {"vmid": 101, "type": "lxc", "status": "stopped", "name": "alpha", "node": "pve-a"},
                    {"vmid": 200, "type": "qemu", "status": "running", "name": "beta", "node": ""},
                    {"vmid": None, "type": "", "status": "", "name": "", "node": ""},
                ]
            },
        )

    def test_shell_wrapper_supports_json_only_as_optional_argument(self):
        payload = {"data": [{"vmid": 100, "type": "qemu", "status": "running", "name": "app"}]}
        command = (
            "payload=$1; "
            "resources() { printf '%s' \"$payload\"; }; "
            "source \"$2\"; cmd_list list --json"
        )
        result = subprocess.run(
            ["bash", "-c", command, "bash", json.dumps(payload), str(WRAPPER)],
            text=True,
            capture_output=True,
            check=True,
        )

        self.assertEqual(json.loads(result.stdout)["guests"][0]["vmid"], 100)


if __name__ == "__main__":
    unittest.main()

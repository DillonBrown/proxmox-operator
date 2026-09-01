#!/usr/bin/env python3
"""Regression tests for the read-only QEMU/LXC guest-memory baseline."""

import json
import pathlib
import subprocess
import unittest


REPOSITORY = pathlib.Path(__file__).resolve().parents[1]
FIXTURES = REPOSITORY / "tests" / "fixtures" / "guest_memory"
FORMATTER = REPOSITORY / "lib/proxmoxctl/guest_memory.py"
WRAPPER = REPOSITORY / "lib/proxmoxctl/guest.sh"


class GuestMemoryTest(unittest.TestCase):
    def run_fixture(self, guest_type, config_name, status_name, vmid="100", name="app"):
        result = subprocess.run(
            [
                "python3", str(FORMATTER), guest_type, vmid, name,
                str(FIXTURES / config_name), str(FIXTURES / status_name),
            ],
            text=True,
            capture_output=True,
            check=True,
        )
        return json.loads(result.stdout)

    def test_qemu_normalizes_memory_and_supported_signals(self):
        result = self.run_fixture("qemu", "qemu_config.json", "qemu_status.json")
        self.assertEqual(result["guest"], {"vmid": 100, "name": "app", "type": "qemu", "status": "running"})
        self.assertEqual(result["memory"], {"configured_limit_bytes": 6442450944, "current_bytes": 600, "resident_bytes": 700})
        self.assertEqual(result["signals"]["balloon"]["free_bytes"], 25)
        self.assertEqual(result["signals"]["swap"], {"balloon_in_bytes": 1, "balloon_out_bytes": 2})
        self.assertFalse(result["capabilities"]["process_memory"]["available"])

    def test_lxc_normalizes_supported_status_without_guest_fabrication(self):
        result = self.run_fixture("lxc", "lxc_config.json", "lxc_status.json", vmid="200", name="container")
        self.assertEqual(result["guest"], {"vmid": 200, "name": "container", "type": "lxc", "status": "running"})
        self.assertEqual(result["memory"], {"configured_limit_bytes": 536870912, "current_bytes": 1234, "resident_bytes": None})
        self.assertEqual(result["signals"]["balloon"], {"actual_bytes": None, "total_bytes": None, "free_bytes": None, "maximum_bytes": None})
        self.assertEqual(result["signals"]["pressure"], {"memory_some": None, "memory_full": None})
        self.assertEqual(result["capabilities"]["guest_meminfo"]["available"], False)

    def test_missing_or_malformed_metrics_are_null(self):
        result = self.run_fixture("qemu", "missing_config.json", "missing_status.json")
        self.assertEqual(result["memory"], {"configured_limit_bytes": None, "current_bytes": None, "resident_bytes": None})
        self.assertIsNone(result["guest"]["status"])
        self.assertIsNone(result["signals"]["swap"]["balloon_in_bytes"])

    def test_shell_wrapper_requires_exactly_one_selector(self):
        command = (
            "guest_info() { TYPE=qemu; VMID=100; NAME=app; }; "
            "get_config_json() { printf '%s' '{\"data\":{\"memory\":64}}'; }; "
            "get_status_json() { printf '%s' '{\"data\":{\"status\":\"running\",\"mem\":1}}'; }; "
            "source \"$1\"; cmd_guest_memory guest-memory 100"
        )
        result = subprocess.run(["bash", "-c", command, "bash", str(WRAPPER)], text=True, capture_output=True, check=True)
        self.assertEqual(json.loads(result.stdout)["memory"]["configured_limit_bytes"], 64 * 1024 * 1024)

        missing = subprocess.run(
            ["bash", "-c", "source \"$1\"; cmd_guest_memory guest-memory", "bash", str(WRAPPER)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("Usage: proxmoxctl guest-memory", missing.stderr)

        extra = subprocess.run(
            ["bash", "-c", "source \"$1\"; cmd_guest_memory guest-memory 100 extra", "bash", str(WRAPPER)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(extra.returncode, 0)
        self.assertIn("Usage: proxmoxctl guest-memory", extra.stderr)

    def test_inventory_failure_is_sanitized_and_stops_before_follow_up_queries(self):
        failure_fixture = FIXTURES / "inventory_failure.stderr"
        command = (
            "guest_info() { cat \"$2\" >&2; return 1; }; "
            "get_config_json() { echo config-queried >&2; return 1; }; "
            "get_status_json() { echo status-queried >&2; return 1; }; "
            "source \"$1\"; cmd_guest_memory guest-memory 100"
        )
        result = subprocess.run(
            ["bash", "-c", command, "bash", str(WRAPPER), str(failure_fixture)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "Unable to resolve guest from Proxmox inventory.\n")


if __name__ == "__main__":
    unittest.main()

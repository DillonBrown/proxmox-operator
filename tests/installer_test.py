#!/usr/bin/env python3
"""Regression tests for the proxmoxctl installer manifest."""

import pathlib
import re
import unittest


REPOSITORY = pathlib.Path(__file__).resolve().parents[1]
INSTALLER = REPOSITORY / "install.sh"


class InstallerTest(unittest.TestCase):
    def test_guest_memory_formatter_is_installed(self):
        content = INSTALLER.read_text(encoding="utf-8")
        match = re.search(r"MODULES=\((.*?)\n\)", content, re.DOTALL)
        self.assertIsNotNone(match)
        modules = set(re.findall(r"^\s{4}(\S+)\s*$", match.group(1), re.MULTILINE))
        self.assertIn("guest_memory.py", modules)
        self.assertTrue((REPOSITORY / "lib/proxmoxctl/guest_memory.py").is_file())


if __name__ == "__main__":
    unittest.main()

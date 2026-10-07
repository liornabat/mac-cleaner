#!/usr/bin/env python3
"""Regression checks for release metadata and tag validation, without modifying the repo."""
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name('version.py')
spec = importlib.util.spec_from_file_location('version_tool', SCRIPT)
version_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(version_tool)


class VersionTests(unittest.TestCase):
    def test_invalid_metadata_cannot_reach_packaging(self):
        cases = [
            {'version': '1.2', 'build': 1},
            {'version': '01.2.3', 'build': 1},
            {'version': '1.2.3-beta', 'build': 1},
            {'version': '1.2.3', 'build': 0},
            {'version': '1.2.3', 'build': True},
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'version.json'
            for value in cases:
                path.write_text(json.dumps(value))
                with self.assertRaises(ValueError):
                    version_tool.read_version(path)

    def test_mismatched_tag_is_rejected(self):
        value = version_tool.read_version()
        valid = subprocess.run([str(SCRIPT), 'validate', '--expect-tag', 'v' + value['version']], capture_output=True)
        invalid = subprocess.run([str(SCRIPT), 'validate', '--expect-tag', 'v9999.9999.9999'], capture_output=True)
        self.assertEqual(valid.returncode, 0)
        self.assertNotEqual(invalid.returncode, 0)
        self.assertIn(b'does not match', invalid.stderr)

    def test_bumping_resets_components_and_increments_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / 'scripts/version.py'
            source = root / 'Sources/MacClean/Resources/AppVersion.json'
            script.parent.mkdir(parents=True)
            source.parent.mkdir(parents=True)
            script.write_bytes(SCRIPT.read_bytes())
            for increment, expected in [('patch', '1.2.4'), ('minor', '1.3.0'), ('major', '2.0.0')]:
                source.write_text(json.dumps({'version': '1.2.3', 'build': 7}))
                subprocess.run(['python3', str(script), 'bump', increment], check=True, capture_output=True)
                self.assertEqual(json.loads(source.read_text()), {'version': expected, 'build': 8})


if __name__ == '__main__':
    unittest.main()

"""Acceptance build reuse must reject changed source and changed artifacts."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("build_cache", Path(__file__).resolve().parents[1] / "scripts/accept/build_cache.py")
cache = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cache)


class BuildCacheTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.patches = [patch.object(cache, "ROOT", self.root),
            patch.object(cache, "RECEIPT", self.root / "build/accept-build.json"),
            patch.object(cache.subprocess, "check_output", return_value="fixed-toolchain")]
        for item in self.patches:
            item.start()
        for name in ("build.sh", "Info.plist", "icon/AppIcon.icns", "Sources/main.swift",
                     "Tests/main.swift", "Resources/words.json", "build/tests",
                     "build/LiteGauge.app/Contents/MacOS/LiteGauge"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(name)

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.temp.cleanup()

    def invoke(self, *args):
        with patch.object(cache.sys, "argv", ["build_cache.py", *args]):
            return cache.main()

    def test_reuses_only_unchanged_source_and_output(self):
        key = cache.input_key()
        self.assertEqual(self.invoke("save", key), 0)
        self.assertEqual(self.invoke("check", key), 0)
        (self.root / "Sources/main.swift").write_text("changed-source")
        self.assertNotEqual(cache.input_key(), key)
        self.assertEqual(self.invoke("check", cache.input_key()), 1)

    def test_changed_resource_and_missing_test_reject_reuse(self):
        key = cache.input_key()
        self.invoke("save", key)
        (self.root / "build/LiteGauge.app/Contents/Resources").mkdir()
        (self.root / "build/LiteGauge.app/Contents/Resources/new").write_text("new")
        self.assertEqual(self.invoke("check", key), 1)
        (self.root / "build/tests").unlink()
        self.assertEqual(self.invoke("check", key), 1)

    def test_drift_during_build_does_not_replace_receipt(self):
        key = cache.input_key()
        self.invoke("save", key)
        original = cache.RECEIPT.read_bytes()
        (self.root / "Resources/words.json").write_text("changed-input")
        with self.assertRaises(RuntimeError):
            self.invoke("save", key)
        self.assertEqual(cache.RECEIPT.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()

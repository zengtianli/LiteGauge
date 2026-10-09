"""Bind an acceptance build to current inputs and every actual output byte."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
RECEIPT = ROOT / "build/accept-build.json"


def digest_files(paths):
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(str(path.relative_to(ROOT)).encode() + b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def input_key():
    paths = [ROOT / name for name in ("build.sh", "Info.plist", "icon/AppIcon.icns")]
    for name in ("Sources", "Tests", "Resources"):
        paths.extend(p for p in (ROOT / name).rglob("*") if p.is_file())
    toolchain = [subprocess.check_output(command, text=True).strip() for command in (
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"],
        ["xcrun", "swiftc", "--version"],
    )]
    return hashlib.sha256(json.dumps({"files": digest_files(paths), "toolchain": toolchain,
        "signing_identity": os.environ.get("CODE_SIGN_IDENTITY", "")}, sort_keys=True).encode()).hexdigest()


def outputs():
    app = ROOT / "build/LiteGauge.app"
    exe = app / "Contents/MacOS/LiteGauge"
    tests = ROOT / "build/tests"
    if not exe.is_file() or not tests.is_file():
        raise FileNotFoundError("acceptance app or core tests missing")
    return digest_files([tests, *(p for p in app.rglob("*") if p.is_file())])


def main():
    command = sys.argv[1]
    if command == "key":
        print(input_key())
        return 0
    key = sys.argv[2]
    if command == "check":
        try:
            receipt = json.loads(RECEIPT.read_text())
            return 0 if receipt == {"inputs": key, "outputs": outputs()} else 1
        except (OSError, ValueError):
            return 1
    if command == "save":
        if input_key() != key:
            raise RuntimeError("build inputs changed during compilation; not caching")
        temporary = RECEIPT.with_suffix(".tmp")
        temporary.write_text(json.dumps({"inputs": key, "outputs": outputs()}, indent=2) + "\n")
        temporary.replace(RECEIPT)
        return 0
    raise ValueError("expected key, check or save")


if __name__ == "__main__":
    sys.exit(main())

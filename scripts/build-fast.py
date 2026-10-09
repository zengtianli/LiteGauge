#!/usr/bin/env python3
"""Run the original app build recipe while reusing strictly verified core tests.

The acceptance build must already have passed with identical inputs and outputs.
Only the two core-test compile/run lines are omitted; all app compilation and
local signing still come from build.sh. No notarization or release operation.
"""
from pathlib import Path
import json
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/accept"))
import build_cache


def main():
    key = build_cache.input_key()
    try:
        receipt = json.loads(build_cache.RECEIPT.read_text())
        valid = receipt == {"inputs": key, "outputs": build_cache.outputs()}
    except (OSError, ValueError):
        valid = False
    if not valid:
        print("No verified current-source core tests; run functionality acceptance first.", file=sys.stderr)
        return 1
    lines = (ROOT / "build.sh").read_text().splitlines(keepends=True)
    candidates = [i for i, line in enumerate(lines)
        if line.startswith('"${COMPILER[@]}" ') and line.rstrip().endswith(" -o build/tests")]
    if len(candidates) != 1 or lines[candidates[0] + 1].strip() != "build/tests":
        print("Original build recipe changed; cannot safely reuse its test step.", file=sys.stderr)
        return 1
    i = candidates[0]
    print(f"Reusing passed core tests for identical inputs: {key}", flush=True)
    result = subprocess.run(["/bin/bash", "-c", "".join(lines[:i] + lines[i + 2:]), str(ROOT / "build.sh")], cwd=ROOT)
    if result.returncode:
        return result.returncode
    if build_cache.input_key() != key:
        raise RuntimeError("Build inputs changed during fast build")
    build_cache.RECEIPT.write_text(json.dumps({"inputs": key, "outputs": build_cache.outputs()}, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

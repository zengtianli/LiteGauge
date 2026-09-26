#!/usr/bin/env python3
"""Verify deployed bytes, download integrity, and HTTP video seeking support."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BASE = 'https://litegauge.tianli.cyou/'

def get(url, headers=None):
    # curl tolerates the local network proxy's interrupted HTTP responses better
    # than urllib; retries are bounded and only perform read-only GETs.
    with tempfile.TemporaryDirectory(prefix='litegauge-verify-') as directory:
        folder = Path(directory)
        command = ['curl', '--silent', '--show-error', '--fail-with-body', '--location',
                   '--retry', '2', '--retry-all-errors', '--max-time', '45',
                   '--user-agent', 'LiteGauge-Release-Check', '--dump-header', str(folder/'headers'),
                   '--output', str(folder/'body'), '--write-out', '%{http_code}']
        for key, value in (headers or {}).items():
            command.extend(['--header', key+': '+value])
        result = subprocess.run(command + [url], capture_output=True, text=True, check=True)
        lines = (folder/'headers').read_text().strip().split('\n\n')[-1].splitlines()
        response_headers = dict(line.split(': ', 1) for line in lines if ': ' in line)
        return int(result.stdout), response_headers, (folder/'body').read_bytes()

site = ROOT / 'dist/site'
for path in sorted(site.rglob('*')):
    if not path.is_file():
        continue
    relative = path.relative_to(site).as_posix()
    status, _, content = get(BASE + relative)
    assert status == 200 and content == path.read_bytes(), f'Deployed content mismatch: {relative}'
    print('Verified:', relative)
release = json.loads((site/'release.json').read_text())
for asset in (release, release.get('dmg')):
    if not asset:
        continue
    status, _, content = get(asset['download_url'])
    assert status == 200 and hashlib.sha256(content).hexdigest() == asset['sha256'], asset['filename']
    print('Download SHA256 verified:', asset['filename'])
status, headers, content = get(BASE+'media/demo.mp4', {'Range':'bytes=0-1023'})
assert status == 206 and len(content) == 1024, (status, len(content))
assert any(k.lower() == 'content-range' for k in headers), headers
print('Video HTTP Range: 206. Browser playback is verified separately.')

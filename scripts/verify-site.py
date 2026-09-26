#!/usr/bin/env python3
"""Verify deployed bytes, download integrity, and HTTP video seeking support."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
BASE = 'https://litegauge.tianli.cyou/'

def get(url, headers=None):
    req = urllib.request.Request(url, headers={'User-Agent': 'LiteGauge-Release-Check', **(headers or {})})
    with urllib.request.urlopen(req, timeout=45) as response:
        return response.status, dict(response.headers), response.read()

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

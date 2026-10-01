#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/media docs/media
xcrun swiftc -O -sdk "$(xcrun --sdk macosx --show-sdk-path)" Sources/Metrics.swift Sources/App.swift scripts/capture/main.swift -o build/media/capture
build/media/capture build/media
cp build/media/panel.png build/media/menubar.png docs/media/
ffmpeg -hide_banner -loglevel error -y -framerate 1 -i build/media/frames/%03d.png -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -r 30 -movflags +faststart docs/media/demo.mp4
ffmpeg -hide_banner -loglevel error -y -i docs/media/demo.mp4 -frames:v 1 -q:v 2 docs/media/demo-poster.jpg
python3 - <<'PY'
import json, pathlib, datetime, hashlib, plistlib
root = pathlib.Path('.')
media = root / 'docs/media'
(media / 'demo.zh.vtt').write_text('''WEBVTT

00:00.000 --> 00:08.000
左侧 CPU 百分比，右侧两条依次表示内存、磁盘已用比例。

00:08.000 --> 00:16.000
详情同时显示内存压力和交换空间，占用高不一定代表内存不足。

00:16.000 --> 00:24.000
磁盘详情显示剩余空间；日常点击菜单或按 ⌘R 可立即刷新。
''')
sources = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [root/'Sources/App.swift', root/'Sources/Metrics.swift']}
version = plistlib.loads((root / 'Info.plist').read_bytes())['CFBundleShortVersionString']
manifest = {'version': version, 'recorded_at': datetime.datetime.now().astimezone().isoformat(),
    'method': 'Production AppKit views rendered offscreen; 24 seconds of real MetricsSampler readings. No synthetic clicks or desktop screen recording.',
    'screenshots': 'Deterministic fixture: CPU 22%, memory 10/16 GiB, disk 180/500 GB free. Same production renderer.',
    'coverage': ['Compact 56-point status indicator', 'CPU updates at 2-second cadence', 'Memory pressure and swap', 'Disk remaining capacity'],
    'not_covered': ['Finder installation', 'Actual menu clicks and keyboard actions', 'Actual sleep/wake cycle'],
    'sources_sha256': sources, 'raw': 'build/media/frames/', 'samples': 'build/media/samples.json',
    'clips': [{'start':0,'end':8,'topic':'CPU and status item'}, {'start':8,'end':16,'topic':'Memory pressure'}, {'start':16,'end':24,'topic':'Disk remaining capacity'}]}
(media/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
PY
echo 'Media: docs/media/'

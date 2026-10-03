#!/usr/bin/env python3
"""Build LiteGauge's portable, dependency-free product website.

Release values come from build/release/release.json; resource measurements come
only from perf/lightweight.json. The small local renderer follows the shared
app-lightweight metric contract without importing a machine-local workspace.
facts.json (the portal's published numbers) comes from the shared generator in
the apps-portal checkout when present; a bare clone builds the page without it.
"""
from __future__ import annotations

import argparse
import hashlib
from html import escape
import json
import os
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SITE_URL = "https://litegauge.tianli.cyou"
GITHUB_URL = "https://github.com/zengtianli/LiteGauge"
MEDIA = ("menubar.png", "panel.png", "demo.mp4", "demo-poster.jpg", "demo.zh.vtt")
PORTAL_SITE = Path.home() / "Apps/apps-portal/site"
PRODUCT_ID = "litegauge"  # products.yaml id / portal card data-product


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def decimal_mb(data: dict, name: str) -> float | None:
    if data.get(name + "_bytes") is not None:
        return float(data[name + "_bytes"]) / 1_000_000
    if data.get(name + "_mb") is not None:
        return float(data[name + "_mb"]) * 1024 * 1024 / 1_000_000
    return None


def mb(value: float | None) -> str:
    return "未测" if value is None else f"{value:.1f}"


def performance_section(perf: dict, release: dict) -> str:
    size, idle = perf.get("size", {}), perf.get("idle", {})
    download = decimal_mb(size, "download")
    installed = decimal_mb(size, "installed")
    footprint = idle.get("footprint_mb")
    memory = None if footprint is None else float(footprint) * 1024 * 1024 / 1_000_000
    cpu = idle.get("cpu_pct")
    speeds = perf.get("speed_gui", []) + perf.get("speed_cli", [])
    speed = next((item for item in speeds if item.get("headline")), next(iter(speeds), {}))
    ms = speed.get("median_ms")
    speed_value = "未测" if ms is None else f"{float(ms) / 1000:.1f}" if float(ms) >= 1000 else f"{float(ms):.0f}"
    speed_unit = "" if ms is None else "s" if float(ms) >= 1000 else "ms"
    speed_label = speed.get("label", "启动或关键操作")
    speed_note = speed.get("method", "未提供本版本的速度测量。")
    if speed.get("key") == "first_sample":
        speed_label = "首个 CPU 读数"
        speed_note = "应用初始化后首次有效读数，含采样等待；单次记录，不代表完整冷启动。"
    cards = [
        ("download", mb(download), "MB" if download is not None else "", "安装包", f"下载文件；安装后占用 {mb(installed)} MB。"),
        ("memory", mb(memory), "MB" if memory is not None else "", "空闲内存", "phys_footprint，活动监视器内存列同口径。"),
        ("cpu", "未测" if cpu is None else f"{float(cpu):.2f}".rstrip("0").rstrip("."), "%" if cpu is not None else "", "空闲 CPU", f"菜单收起，{idle.get('window_s', '未知')} 秒采样窗平均占用。"),
        ("speed", speed_value, speed_unit, speed_label, speed_note),
    ]
    def card_note(metric: str, note: str) -> str:
        result = escape(note)
        if metric == "download" and installed is not None:
            value = escape(mb(installed) + " MB")
            result = result.replace(value, "<span data-perf-metric='installed'>" + value + "</span>")
        return result

    rendered = "".join(
        "<article><p class='perf-value' data-perf-metric='" + metric + "'><strong>" + escape(value) + "</strong> " + escape(unit) + "</p>"
        "<h3>" + escape(label) + "</h3><p>" + card_note(metric, note) + "</p></article>"
        for metric, value, unit, label, note in cards
    )
    method = " · ".join(str(perf[key]) for key in ("device", "measured_at") if perf.get(key))
    description = str(perf.get("data", ""))
    limit = perf.get("speed_cold_start", {})
    limit_text = "完整冷启动尚未测量；上方速度是进程内首次有效 CPU 数值，含采样等待。" if limit.get("status") == "未测" else ""
    return (
        "<section id='light' class='lw-perf wrap' aria-labelledby='light-title'><div class='section-title'>"
        "<p class='eyebrow'>轻量，有数字可查</p><h2 id='light-title'>只做需要的事，也看自己的占用。</h2><p>"
        + escape(str(perf.get("why", ""))) + "</p></div><div class='perf-grid'>" + rendered + "</div>"
        "<p class='fine'>v" + escape(str(perf["version"])) + " · " + escape(method) + " · " + escape(description)
        + "。内存含主进程与辅助进程；CPU 为进程 CPU 时间增量 ÷ 墙钟，100% 代表一个核心。MB 按十进制显示。"
        "<a href='lightweight.json'>查看实测证据</a>。</p>"
        + ("<p class='measurement-limit'>" + escape(limit_text) + "</p>" if limit_text else "")
        + ("<p class='measurement-limit'>以上为 v" + escape(str(perf['version'])) + " 的历史实测，包括该版本的包大小；不代表当前 v" + escape(str(release['version'])) + "。当前下载大小见下载入口，本轮未重复运行性能采样。</p>" if str(perf['version']).split(' ')[0] != str(release['version']) else "") + "</section>"
    )


def write_facts(output: Path, version: str) -> None:
    """Publish facts.json at the homepage root so it deploys with this page."""
    if not (PORTAL_SITE / "product_facts.py").is_file():
        print("facts.json not written — shared generator unavailable: " + str(PORTAL_SITE), file=sys.stderr)
        return
    sys.path.insert(0, str(PORTAL_SITE))
    import product_facts
    facts = product_facts.from_repo(ROOT, product_id=PRODUCT_ID, icon="assets/AppIcon.png")
    if facts["version"] != version:
        raise ValueError(f"facts.json version {facts['version']} (sop.release) differs from the page's v{version}")
    product_facts.write(output, facts)


def build(args: argparse.Namespace) -> None:
    release_path = args.release.resolve()
    release = read_json(release_path)
    perf_path = ROOT / "perf/lightweight.json"
    perf = read_json(perf_path)
    for key in ("version", "filename", "sha256", "bytes", "notarized", "minimum_macos", "architecture", "download_url"):
        if key not in release:
            raise ValueError(f"release metadata missing {key}")
    if str(perf.get("version", "")).split(" ")[0] != str(release["version"]) and os.environ.get("APP_RELEASE_KEEP_HISTORY") != "1":
        raise ValueError("Release and performance versions differ; measure this release first")
    if Path(release["filename"]).name != release["filename"] or not str(release["filename"]).endswith(".zip"):
        raise ValueError("Release filename must be a plain ZIP filename")
    if not re.fullmatch(r"[0-9a-fA-F]{64}", str(release["sha256"])):
        raise ValueError("Release SHA-256 must have 64 hexadecimal characters")
    if not str(release["download_url"]).startswith(GITHUB_URL + "/releases/download/"):
        raise ValueError("Download URL must point at this product's GitHub release")
    if perf.get("size", {}).get("download_bytes") != release["bytes"] and os.environ.get("APP_RELEASE_KEEP_HISTORY") != "1":
        raise ValueError("perf/lightweight.json size.download_bytes must match this release's bytes")
    archive = release_path.parent / release["filename"]
    if archive.exists():
        if archive.stat().st_size != release["bytes"] or hashlib.sha256(archive.read_bytes()).hexdigest() != str(release["sha256"]).lower():
            raise ValueError("Release archive differs from its metadata")
    missing = [name for name in MEDIA if not (ROOT / "docs/media" / name).is_file()]
    if missing and not args.allow_missing_media:
        raise ValueError("Missing real media: " + ", ".join(missing))
    architecture = str(release["architecture"])
    if architecture not in ("arm64", "Apple Silicon"):
        raise ValueError("Website currently describes the Apple Silicon release only")
    requirement = f"Apple Silicon · macOS {release['minimum_macos']}+"
    if release["notarized"]:
        signing_note = "已通过 Apple 公证。"
        first_open = "<p>首次打开时，macOS 可能会询问是否打开从互联网下载的 App。核对应用名称为 LiteGauge 后确认即可。轻仪不需要辅助功能、屏幕录制或完全磁盘访问权限。</p>"
    else:
        signing_note = "当前版本未经过 Apple 公证。"
        first_open = (
            "<p>当前下载包采用本地签名，尚未经过 Apple 公证。首次尝试打开后，如果 macOS 提示无法验证开发者，"
            "请先确认文件来自本页的官方 Release，再到「系统设置 → 隐私与安全性」选择「仍要打开」，按系统提示确认。"
            "系统可能要求 Mac 登录密码或 Touch ID。轻仪不需要辅助功能、屏幕录制或完全磁盘访问权限。"
            "<a href='https://support.apple.com/zh-cn/102445'>查看 Apple 的说明 ↗</a></p>"
        )
    schema = {
        "@context": "https://schema.org", "@type": "SoftwareApplication", "name": "轻仪 LiteGauge",
        "applicationCategory": "UtilitiesApplication", "operatingSystem": requirement,
        "softwareVersion": str(release["version"]), "url": SITE_URL, "downloadUrl": release["download_url"],
        "description": "56 点宽度的原生 macOS 菜单栏 CPU、内存与启动磁盘监控工具。",
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
        "author": {"@type": "Person", "name": "Tianli", "url": "https://github.com/zengtianli"},
    }
    replacements = {
        "SITE_URL": SITE_URL, "GITHUB_URL": GITHUB_URL, "VERSION": release["version"],
        "DOWNLOAD_URL": release["download_url"], "RELEASE_URL": GITHUB_URL + "/releases/tag/v" + str(release["version"]),
        "DOWNLOAD_MB": mb(float(release["bytes"]) / 1_000_000), "FILENAME": release["filename"],
        "SHA256": release["sha256"], "SYSTEM_REQUIREMENT": requirement, "SIGNING_NOTE": signing_note,
        "MENU_WIDTH": perf.get("menu_bar", {}).get("width_points", 56),
    }
    html = (ROOT / "site/index.html").read_text(encoding="utf-8")
    for key, value in replacements.items():
        html = html.replace("{{" + key + "}}", escape(str(value), quote=True))
    html = html.replace("{{PERFORMANCE_SECTION}}", performance_section(perf, release))
    html = html.replace("{{FIRST_OPEN_HTML}}", first_open)
    html = html.replace("{{SCHEMA_JSON}}", json.dumps(schema, ensure_ascii=False).replace("<", "\\u003c"))
    if re.search(r"\{\{[A-Z_]+\}\}", html):
        raise ValueError("Unresolved template fields in the site")
    output = args.out.resolve()
    if output == ROOT or output == ROOT / "site" or ROOT not in output.parents:
        raise ValueError("Build output must be a separate directory inside this repository")
    (output / "media").mkdir(parents=True, exist_ok=True)
    (output / "assets").mkdir(parents=True, exist_ok=True)
    (output / "index.html").write_text(html, encoding="utf-8")
    shutil.copy2(ROOT / "site/style.css", output / "style.css")
    shutil.copy2(ROOT / "icon/AppIcon.png", output / "assets/AppIcon.png")
    for name in MEDIA:
        source = ROOT / "docs/media" / name
        if source.is_file():
            shutil.copy2(source, output / "media" / name)
    public_release = {key: release[key] for key in ("version", "filename", "sha256", "bytes", "notarized", "minimum_macos", "architecture", "download_url")}
    if release.get("dmg"):
        public_release["dmg"] = {key: release["dmg"][key] for key in ("filename", "sha256", "bytes", "download_url")}
    (output / "release.json").write_text(json.dumps(public_release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    shutil.copy2(perf_path, output / "lightweight.json")
    write_facts(output, str(release["version"]))
    (output / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {SITE_URL}/sitemap.xml\n", encoding="utf-8")
    (output / "sitemap.xml").write_text(f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>{SITE_URL}/</loc></url></urlset>\n', encoding="utf-8")
    print(f"Built {output.relative_to(ROOT)}/index.html for v{release['version']}")
    if missing:
        print("PREVIEW ONLY — missing media: " + ", ".join(missing), file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, default=ROOT / "build/release/release.json")
    parser.add_argument("--out", type=Path, default=ROOT / "dist/site")
    parser.add_argument("--allow-missing-media", action="store_true", help="Local layout preview only; never deploy this incomplete output")
    args = parser.parse_args()
    try:
        build(args)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"Cannot build site: {error}\n")


if __name__ == "__main__":
    main()

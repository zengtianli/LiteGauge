#!/usr/bin/env python3
"""Build LiteGauge's static product website into dist/site.

Release values come from the published release record (release/latest.json, the
file project.yaml registers as sop.release); the matching ZIP is copied into the
site so the page's download, release.json and site-manifest.json describe the
same bytes. Resource numbers come only from perf/lightweight.json and are
rendered by the shared perf_block in the apps-portal checkout, which also
supplies facts.json (the portal's published numbers). The output directory is
replaced as a whole and ends with site-manifest.json listing every public file.
"""
from __future__ import annotations

import argparse
import hashlib
from html import escape
import json
from pathlib import Path
import re
import shutil
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
SITE_URL = "https://litegauge.tianli.cyou"
GITHUB_URL = "https://github.com/zengtianli/LiteGauge"
# The 36 px tall menu-bar strip is below the page's minimum screenshot size; the demo video shows it enlarged.
MEDIA = ("panel.png", "diagnosis.png", "demo.mp4", "demo-poster.jpg", "demo.zh.vtt")
PORTAL_SITE = Path.home() / "Apps/apps-portal/site"
PRODUCT_ID = "litegauge"  # products.yaml id / portal card data-product
MANIFEST = "site-manifest.json"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def shared(module: str):
    """Import the shared portal module; the page's numbers are never formatted locally."""
    if not (PORTAL_SITE / (module + ".py")).is_file():
        raise ValueError("shared renderer unavailable: " + str(PORTAL_SITE / (module + ".py")))
    if str(PORTAL_SITE) not in sys.path:
        sys.path.insert(0, str(PORTAL_SITE))
    return __import__(module)


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def release_label(release: dict) -> str:
    return "v" + str(release["version"]) + (f" ({release['build']})" if release.get("build") else "")


def same_version(perf: dict, release: dict) -> bool:
    return str(perf.get("version", "")).split(" ")[0] == str(release["version"])


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if not header.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"{path.name} is not a PNG")
    return struct.unpack(">II", header[16:24])


def performance_section(perf_path: Path, raw: dict, release: dict) -> str:
    perf_block = shared("perf_block")
    perf = perf_block.load({"perf": str(perf_path)})
    if perf is None:
        raise ValueError("perf/lightweight.json cannot be read by the shared renderer")
    body = perf_block.section(perf).replace("class='section wrap perf'", "class='lw-perf wrap'")
    if "class='lw-perf wrap'" not in body or not body.endswith("</section>"):
        raise ValueError("shared perf_block.section changed its markup; adapt the site build")
    notes = ["<p class='fine'><a href='lightweight.json'>查看实测证据</a>。MB 按十进制显示；CPU 的 100% 代表一个核心。</p>"]
    cold = raw.get("speed_cold_start", {})
    if cold.get("status") == "未测":
        notes.append("<p class='measurement-limit'>完整冷启动：未测。" + escape(str(cold.get("reason", "没有记录原因。")))
                     + "上方速度是进程内首次有效 CPU 数值，含采样等待。</p>")
    if not same_version(raw, release):
        current = escape(release_label(release))
        notes.append(
            "<p class='measurement-limit'>以上是 v" + escape(str(raw["version"])) + " 的历史实测，包括该版本的包大小，不代表当前公开下载的 "
            + current + "。" + current + " 的下载包为 " + escape(perf_block.size_mb(int(release["bytes"])))
            + "；它的安装后大小、内存、CPU 与速度未测：perf/lightweight.json 里还没有该版本的采样记录。</p>")
    return body[:-len("</section>")] + "".join(notes) + "</section>"


def media_scope(release: dict) -> tuple[str, str]:
    """Say which build the screenshots and video were recorded from (docs/media/manifest.json)."""
    record = ROOT / "docs/media/manifest.json"
    recorded = str(read_json(record).get("version", "")).split(" ")[0] if record.is_file() else ""
    if not recorded:
        return "录制版本未登记", "<p class='measurement-limit'>截图与视频的录制版本未登记，界面以实际下载的版本为准。</p>"
    if recorded == str(release["version"]):
        return "录自 v" + escape(recorded), ""
    return ("录自 v" + escape(recorded) + " 本地构建",
            "<p class='measurement-limit'>本页截图与视频录自 v" + escape(recorded) + " 本地构建，与当前公开下载的 "
            + escape(release_label(release)) + " 不是同一版本；画面和下载到的界面可能不同，各版本的变化见"
            "<a href='" + escape(GITHUB_URL + "/releases", quote=True) + "'>更新记录</a>。</p>")


def find_archive(release_path: Path, release: dict, explicit: Path | None) -> Path:
    """The published ZIP, byte-checked against the release record before it is offered on the page."""
    candidates = [explicit] if explicit else [release_path.parent / release["filename"], ROOT / "build/release" / release["filename"]]
    archive = next((path for path in candidates if path and path.is_file()), None)
    if archive is None:
        raise ValueError(f"{release['filename']} not found; download {release['download_url']} into build/release/ or pass --archive")
    if archive.stat().st_size != release["bytes"] or sha256(archive) != str(release["sha256"]).lower():
        raise ValueError(f"{archive} differs from the release record (bytes or SHA-256)")
    return archive


def write_facts(output: Path, release: dict) -> None:
    """Publish facts.json at the homepage root so it deploys with this page."""
    product_facts = shared("product_facts")
    version = str(release['version'])
    facts = product_facts.from_repo(ROOT, product_id=PRODUCT_ID, icon="assets/AppIcon.png")
    if facts["version"] != version:
        raise ValueError(f"facts.json version {facts['version']} (sop.release) differs from the page's v{version}")
    measured = read_json(ROOT / 'perf/lightweight.json')
    if not same_version(measured, release):
        facts.update(download_bytes=release['bytes'], measured_version=measured['version'],
                     historical_reference=True, download_source='verified current release ZIP')
        facts['card_line'] = f"当前下载 {release['bytes'] / 1_000_000:.1f} MB · 历史实测 {escape(measured['version'])}（{escape(measured['measured_at'])}）：" + facts['card_line']
        facts['card_text'] = product_facts.card_text(facts['card_line'])
    product_facts.write(output, facts)


def build(args: argparse.Namespace) -> None:
    release_path = args.release.resolve()
    release = read_json(release_path)
    perf_path = ROOT / "perf/lightweight.json"
    perf = read_json(perf_path)
    for key in ("version", "filename", "sha256", "bytes", "notarized", "minimum_macos", "architecture", "download_url"):
        if key not in release:
            raise ValueError(f"release metadata missing {key}")
    if Path(release["filename"]).name != release["filename"] or not str(release["filename"]).endswith(".zip"):
        raise ValueError("Release filename must be a plain ZIP filename")
    if not re.fullmatch(r"[0-9a-fA-F]{64}", str(release["sha256"])):
        raise ValueError("Release SHA-256 must have 64 hexadecimal characters")
    if not str(release["download_url"]).startswith(GITHUB_URL + "/releases/download/"):
        raise ValueError("Download URL must point at this product's GitHub release")
    if same_version(perf, release) and perf.get("size", {}).get("download_bytes") != release["bytes"]:
        raise ValueError("perf/lightweight.json size.download_bytes must match this release's bytes")
    archive = find_archive(release_path, release, args.archive.resolve() if args.archive else None)
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
    download_path = "downloads/" + release["filename"]
    media_label, media_note = media_scope(release)
    panel = ROOT / "docs/media/panel.png"
    panel_width, panel_height = png_size(panel) if panel.is_file() else (360, 736)
    replacements = {
        "SITE_URL": SITE_URL, "GITHUB_URL": GITHUB_URL, "VERSION": release["version"],
        "DOWNLOAD_PATH": download_path, "RELEASE_URL": GITHUB_URL + "/releases/tag/v" + str(release["version"]),
        "DOWNLOAD_SIZE": shared("perf_block").size_mb(int(release["bytes"])), "FILENAME": release["filename"],
        "SHA256": release["sha256"], "SYSTEM_REQUIREMENT": requirement, "SIGNING_NOTE": signing_note,
        "MENU_WIDTH": perf.get("menu_bar", {}).get("width_points", 56),
        "PANEL_WIDTH": panel_width, "PANEL_HEIGHT": panel_height, "MEDIA_VERSION_LABEL": media_label,
    }
    html = (ROOT / "site/index.html").read_text(encoding="utf-8")
    for key, value in replacements.items():
        html = html.replace("{{" + key + "}}", escape(str(value), quote=True))
    html = html.replace("{{PERFORMANCE_SECTION}}", performance_section(perf_path, perf, release))
    html = html.replace("{{FIRST_OPEN_HTML}}", first_open)
    html = html.replace("{{MEDIA_SCOPE_HTML}}", media_note)
    if re.search(r"\{\{[A-Z_]+\}\}", html):
        raise ValueError("Unresolved template fields in the site")
    target = args.out.resolve()
    if target == ROOT or target == ROOT / "site" or ROOT not in target.parents:
        raise ValueError("Build output must be a separate directory inside this repository")
    # Build beside the target and swap, so files from an earlier build never reach the manifest.
    output = target.with_name(target.name + ".building")
    if output.exists():
        shutil.rmtree(output)
    (output / "media").mkdir(parents=True)
    (output / "assets").mkdir()
    (output / "downloads").mkdir()
    (output / "index.html").write_text(html, encoding="utf-8")
    shutil.copy2(ROOT / "site/style.css", output / "style.css")
    shutil.copy2(ROOT / "icon/AppIcon.png", output / "assets/AppIcon.png")
    shutil.copyfile(archive, output / download_path)
    for name in MEDIA:
        source = ROOT / "docs/media" / name
        if source.is_file():
            shutil.copy2(source, output / "media" / name)
    public_release = {key: release[key] for key in ("version", "filename", "sha256", "bytes", "notarized", "minimum_macos", "architecture", "download_url")}
    if release.get("build"):
        public_release["build"] = str(release["build"])
    if release.get("dmg"):
        public_release["dmg"] = {key: release["dmg"][key] for key in ("filename", "sha256", "bytes", "download_url")}
    (output / "release.json").write_text(json.dumps(public_release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    shutil.copy2(perf_path, output / "lightweight.json")
    write_facts(output, release)
    (output / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {SITE_URL}/sitemap.xml\n", encoding="utf-8")
    (output / "sitemap.xml").write_text(f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>{SITE_URL}/</loc></url></urlset>\n', encoding="utf-8")
    files = [{"path": path.relative_to(output).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size}
             for path in sorted(output.rglob("*")) if path.is_file()]
    manifest = {"schema": 1, "product": PRODUCT_ID, "domain": SITE_URL.removeprefix("https://"), "preview": bool(missing),
                "version": str(release["version"]), "measured_version": str(perf["version"]), "files": files}
    (output / MANIFEST).write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if target.exists():
        shutil.rmtree(target)
    output.rename(target)
    print(f"Built {target.relative_to(ROOT)}/index.html for v{release['version']}; {len(files)} public files in {MANIFEST}")
    if missing:
        print("PREVIEW ONLY — missing media: " + ", ".join(missing), file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, default=ROOT / "release/latest.json",
                        help="Published release record; pass build/release/release.json only to preview an unpublished package")
    parser.add_argument("--archive", type=Path, help="Release ZIP, when it is not beside the record or in build/release/")
    parser.add_argument("--out", type=Path, default=ROOT / "dist/site")
    parser.add_argument("--allow-missing-media", action="store_true", help="Local layout preview only; never deploy this incomplete output")
    args = parser.parse_args()
    try:
        build(args)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"Cannot build site: {error}\n")


if __name__ == "__main__":
    main()

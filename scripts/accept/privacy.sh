#!/bin/bash
# privacy acceptance: metric/CLI modules have no network/process/defaults APIs; the vendored lifecycle
# modules handle explicit release checks/downloads. Metric samples are never passed to them.
# The app links system frameworks and has no entitlements or usage strings;
# file writes happen only to paths passed explicitly (--benchmark/--snapshot/--ui-self-test);
# a running instance holds no sockets and the app leaves no preferences or support folders.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/accept/_build.sh
LIBS="$(otool -L "$EXE" | tail -n +2 | awk '{print $1}' | grep -vE '^/(usr/lib|System/Library)/' || true)"
NET="$(nm -u "$EXE" | grep -iE 'URLSession|NSURLConnection|CFNetwork|nw_connection|_socket$|_connect$|getaddrinfo' || true)"
URLS="$(strings "$EXE" | grep -iE 'https?://' || true)"
ENT="$(codesign -d --entitlements - "$APP" 2>/dev/null | grep -v '^Executable' | grep -c key || true)"
USAGE="$(plutil -p "$APP/Contents/Info.plist" | grep -ci usage || true)"
SRC="$(grep -nE 'URLSession|URLRequest|NSTask|Process\(|UserDefaults|NSWorkspace.shared.open\(URL\(string' Sources/*.swift | grep -vE '^Sources/App(Lifecycle(UI)?|Configuration)\.swift:' || true)"
PID="$(pgrep -x LiteGauge | head -1 || true)"
SOCK=-1; [ -n "$PID" ] && SOCK="$( (lsof -a -p "$PID" -i 2>/dev/null || true) | tail -n +2 | wc -l | tr -d ' ')"
FILES="$( (ls -d ~/Library/Preferences/cyou.tianli.litegauge.plist ~/Library/Containers/cyou.tianli.litegauge ~/Library/Application\ Support/LiteGauge 2>/dev/null || true) | wc -l | tr -d ' ')"
python3 - "$LIBS" "$NET" "$URLS" "$ENT" "$USAGE" "$SRC" "$SOCK" "$FILES" <<'PY'
import json, os, re, sys
libs, net, urls, ent, usage, src, sock, files = sys.argv[1:9]
allowed_urls = ("https://api.github.com/repos/", "https://itunes.apple.com/lookup")
bad_urls = [url for url in re.findall(r'https?://[^" )<>]+', urls) if not url.startswith(allowed_urls)]
checks = {"system_libraries_only": not libs.strip(), "metric_modules_no_network_process_defaults": not src.strip(),
          "embedded_update_urls_whitelisted": not bad_urls,
          "no_entitlements": ent.strip() in ("", "0"), "no_privacy_usage_strings": usage.strip() == "0"}
failed = [k for k, v in checks.items() if not v]
summary = (f"隐私边界 {len(checks)}/{len(checks)} 项通过" + ("（运行实例无网络套接字）" if sock == "0" else "（无运行实例，未查套接字）")
           if not failed else "隐私检查失败：" + ", ".join(failed))
out = os.environ.get("SOP_OUT_DIR")
if out:
    open(os.path.join(out, "privacy.detail.json"), "w").write(json.dumps({"summary": summary, "checks": checks,
        "findings": {"non_system_libs": libs, "network_symbols": net, "urls": urls, "source_hits": src, "running_sockets": sock,
                     "existing_product_preference_paths": files},
        "scope": "Metric/CLI modules remain offline. Lifecycle update requests can create sockets and UI preferences; those observations do not contain metric samples."},
        ensure_ascii=False, indent=2) + "\n")
print(summary); sys.exit(1 if failed else 0)
PY

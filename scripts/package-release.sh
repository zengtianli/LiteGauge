#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != '--skip-notarize' ]; }; then
  echo 'Usage: bash scripts/package-release.sh [--skip-notarize]' >&2
  exit 2
fi
: "${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to a Developer ID Application identity.}"
NOTARIZED=false
AUTH=()
if [ "${1:-}" != '--skip-notarize' ]; then
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    AUTH=(--keychain-profile "$NOTARY_PROFILE")
  elif [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
    KEY_FILE="${NOTARY_KEY_FILE:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
    [ -f "$KEY_FILE" ] || { echo 'Notary API private key file is missing.' >&2; exit 1; }
    AUTH=(--key "$KEY_FILE" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
  else
    echo 'Set NOTARY_PROFILE, or ASC_KEY_ID / ASC_ISSUER_ID / NOTARY_KEY_FILE for notarization.' >&2
    echo 'Use --skip-notarize only for a clearly marked non-notarized test build.' >&2
    exit 1
  fi
fi

bash build.sh
APP="$PWD/build/LiteGauge.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
OUT="$PWD/build/release"
mkdir -p "$OUT"
FILENAME="LiteGauge-${VERSION}-arm64.zip"
DMG_FILENAME="LiteGauge-${VERSION}-arm64.dmg"
SUBMISSION_ID=''
DMG_SUBMISSION_ID=''

if [ "${1:-}" != '--skip-notarize' ]; then
  SUBMIT_ZIP="$OUT/LiteGauge-notary-upload.zip"
  ditto -c -k --keepParent "$APP" "$SUBMIT_ZIP"
  xcrun notarytool submit "$SUBMIT_ZIP" "${AUTH[@]}" --wait --output-format json > "$OUT/notarization-app.json"
  SUBMISSION_ID=$(plutil -extract id raw -o - "$OUT/notarization-app.json")
  STATUS=$(plutil -extract status raw -o - "$OUT/notarization-app.json")
  [ "$STATUS" = Accepted ] || { echo "App notarization failed: $STATUS ($SUBMISSION_ID)" >&2; exit 1; }
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
  NOTARIZED=true
fi

# The distributable ZIP is rebuilt after stapling, so it works offline too.
ditto -c -k --keepParent "$APP" "$OUT/$FILENAME"
STAGING=$(mktemp -d "$OUT/dmg-stage.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/LiteGauge.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -ov -volname LiteGauge -srcfolder "$STAGING" -format UDZO "$OUT/$DMG_FILENAME"
codesign --force --timestamp --sign "$CODE_SIGN_IDENTITY" "$OUT/$DMG_FILENAME"
if [ "$NOTARIZED" = true ]; then
  xcrun notarytool submit "$OUT/$DMG_FILENAME" "${AUTH[@]}" --wait --output-format json > "$OUT/notarization-dmg.json"
  DMG_SUBMISSION_ID=$(plutil -extract id raw -o - "$OUT/notarization-dmg.json")
  STATUS=$(plutil -extract status raw -o - "$OUT/notarization-dmg.json")
  [ "$STATUS" = Accepted ] || { echo "DMG notarization failed: $STATUS ($DMG_SUBMISSION_ID)" >&2; exit 1; }
  xcrun stapler staple "$OUT/$DMG_FILENAME"
  xcrun stapler validate "$OUT/$DMG_FILENAME"
fi
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$OUT/$DMG_FILENAME"

export VERSION FILENAME DMG_FILENAME OUT NOTARIZED SUBMISSION_ID DMG_SUBMISSION_ID
python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
out = Path(os.environ['OUT'])
def asset(filename):
    path = out / filename
    return {'filename': filename, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size,
            'download_url': f'https://github.com/zengtianli/LiteGauge/releases/download/v{os.environ["VERSION"]}/{filename}'}
data = {'version': os.environ['VERSION'], **asset(os.environ['FILENAME']),
        'notarized': os.environ['NOTARIZED'] == 'true', 'minimum_macos': '14.0',
        'architecture': 'arm64', 'signing': 'Developer ID Application with hardened runtime',
        'notarization_id': os.environ['SUBMISSION_ID'],
        'dmg': {**asset(os.environ['DMG_FILENAME']), 'notarization_id': os.environ['DMG_SUBMISSION_ID']}}
(out / 'release.json').write_text(json.dumps(data, indent=2) + '\n')
(out / 'SHA256SUMS').write_text(''.join(f'{item["sha256"]}  {item["filename"]}\n' for item in (data, data['dmg'])))
print(json.dumps(data, indent=2))
PY
echo "Release artifacts: $OUT"

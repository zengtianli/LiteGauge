#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source "${DEPLOY_LIB:-$HOME/Dev/tools/dev/lib/deploy}/core.sh"
vps_load
python3 scripts/build-site.py
rsync -az --delete dist/site/ "$VPS:/var/www/litegauge-next/"
ssh "$VPS" 'set -e; test -s /var/www/litegauge-next/index.html; test -s /var/www/litegauge-next/media/demo.mp4; if [ -d /var/www/litegauge-previous ]; then mv /var/www/litegauge-previous /var/www/litegauge-previous-$(date +%s); fi; if [ -d /var/www/litegauge ]; then mv /var/www/litegauge /var/www/litegauge-previous; fi; mv /var/www/litegauge-next /var/www/litegauge'
http_verify_edge litegauge.tianli.cyou / --expect 200
python3 scripts/verify-site.py

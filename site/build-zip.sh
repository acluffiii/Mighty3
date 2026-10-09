#!/usr/bin/env bash
# Builds sunovabit-site.zip: everything Bluehost needs in public_html, nothing it doesn't.
#   bash site/build-zip.sh
set -euo pipefail
cd "$(dirname "$0")"
rm -f sunovabit-site.zip
zip -r -X -q sunovabit-site.zip . \
  -x 'README.md' 'CNAME.example' 'build-zip.sh' 'sunovabit-site.zip' '*.DS_Store'
echo "Built site/sunovabit-site.zip ($(unzip -l sunovabit-site.zip | tail -1 | awk '{print $2}') files)"

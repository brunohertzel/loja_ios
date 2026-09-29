#!/bin/bash
set -e
cd "$(dirname "$0")"
chmod +x tooling/*.sh
API="${SOFT_API_BASE_URL:-http://softpinhais.ddns.net:8585/ecommerce/api/mobile/v1}"
./tooling/prepare_ios.sh "$API"
./tooling/open_xcode.sh

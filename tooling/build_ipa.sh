#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
API_URL="${1:-${SOFT_API_BASE_URL:-}}"
if [[ "${1:-}" == http://* || "${1:-}" == https://* ]]; then shift; fi
if [[ -z "$API_URL" ]]; then
  API_URL="$(python3 -c 'import json; print(json.load(open("tooling/mobile_app_config_ios.json"))["api_base_url"])')"
fi
bash tooling/prepare_ios.sh "$API_URL"
flutter build ipa --release --dart-define="SOFT_API_BASE_URL=$API_URL" "$@"
echo 'IPA de produção em build/ios/ipa. Exige certificados e perfil Apple válidos.'

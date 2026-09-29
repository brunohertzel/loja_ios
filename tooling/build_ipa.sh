#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
flutter clean
flutter pub get
API="${SOFT_API_BASE_URL:-}"
if [[ -n "$API" ]]; then
  flutter build ipa --release --dart-define="SOFT_API_BASE_URL=$API"
else
  flutter build ipa --release
fi
printf '\nIPA/Archive gerado em build/ios/.\n'

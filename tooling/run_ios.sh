#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
API="${SOFT_API_BASE_URL:-}"
if [[ -n "$API" ]]; then
  exec flutter run --dart-define="SOFT_API_BASE_URL=$API" "$@"
fi
exec flutter run "$@"

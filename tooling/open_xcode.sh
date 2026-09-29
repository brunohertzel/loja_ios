#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ ! -d ios ]]; then
  echo "A pasta ios ainda nao existe. Rode primeiro ./tooling/prepare_ios.sh <API_URL>"
  exit 1
fi
open ios/Runner.xcworkspace

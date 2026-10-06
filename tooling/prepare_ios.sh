#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
command -v flutter >/dev/null || { echo 'Instale Flutter 3.35.5 no Mac.' >&2; exit 1; }
command -v python3 >/dev/null
API_URL="${1:-${SOFT_API_BASE_URL:-}}"
if [[ -z "$API_URL" ]]; then
  API_URL="$(python3 -c 'import json; print(json.load(open("tooling/mobile_app_config_ios.json"))["api_base_url"])')"
fi
flutter pub get
dart run tooling/sync_ios_branding.dart "$API_URL"
python3 tooling/verify_ios_project.py --apply
if [[ -f tooling/.ios_sync/icon_source ]]; then
  while IFS= read -r spec; do
    size="${spec%% *}"; target="${spec#* }"
    sips -s format png -z "$size" "$size" tooling/.ios_sync/icon_source --out "$target" >/dev/null
  done < <(python3 -c 'import json; from pathlib import Path; p=Path("ios/Runner/Assets.xcassets/AppIcon.appiconset"); d=json.loads((p/"Contents.json").read_text()); [print(round(float(x["size"].split("x")[0])*float(x["scale"].rstrip("x"))),p/x["filename"]) for x in d["images"] if x.get("filename")]')
fi
python3 tooling/verify_ios_project.py
(cd ios && pod install)
echo 'iOS preparado. Configure a equipe e os certificados no Xcode antes de compilar.'

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tooling/prepare_ios.sh
flutter build ipa --release --build-name=1.6.28 --build-number="${SOFT_BUILD_NUMBER:-186}" "$@"
echo 'IPA de produção em build/ios/ipa. A assinatura exige certificados e perfil válidos.'

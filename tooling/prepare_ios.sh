#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_URL="${1:-${SOFT_API_BASE_URL:-}}"
TEAM_ID="${SOFT_IOS_TEAM_ID:-}"

if [[ -z "$API_URL" ]]; then
  echo "Uso: ./tooling/prepare_ios.sh http://servidor/ecommerce/api/mobile/v1"
  echo "Ou defina SOFT_API_BASE_URL."
  exit 2
fi

command -v flutter >/dev/null 2>&1 || { echo "Flutter nao encontrado no PATH."; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "Xcode nao encontrado. Instale/abra o Xcode antes de continuar."; exit 1; }
command -v /usr/libexec/PlistBuddy >/dev/null 2>&1 || { echo "PlistBuddy nao encontrado."; exit 1; }

printf '\n[1/9] Flutter / Xcode\n'
flutter --version
xcodebuild -version

printf '\n[2/9] Consultando o modulo Mobile como IOS\n'
dart run tooling/sync_ios_branding.dart "$API_URL"
APP_NAME="$(cat tooling/.ios_sync/app_name)"
BUNDLE_ID="$(cat tooling/.ios_sync/bundle_id)"

printf '\n[3/9] Gerando scaffolding iOS com a sua versao do Flutter\n'
BACKUP="$(mktemp -d -t soft_mobile_ios.XXXXXX)"
cleanup(){ rm -rf "$BACKUP"; }
trap cleanup EXIT
for item in lib tooling docs test; do
  [[ -e "$item" ]] && cp -R "$item" "$BACKUP/$item"
done
for file in pubspec.yaml analysis_options.yaml README.md CHANGELOG.md .gitignore; do
  [[ -e "$file" ]] && cp "$file" "$BACKUP/$file"
done

flutter create . --platforms=ios --org br.com.softsistemas --project-name soft_ecommerce_mobile

for item in lib tooling docs test; do
  rm -rf "$item"
  [[ -e "$BACKUP/$item" ]] && cp -R "$BACKUP/$item" "$item"
done
for file in pubspec.yaml analysis_options.yaml README.md CHANGELOG.md .gitignore; do
  [[ -e "$BACKUP/$file" ]] && cp "$BACKUP/$file" "$file"
done

printf '\n[4/9] Bundle ID / nome do app / deployment target\n'
PBX="ios/Runner.xcodeproj/project.pbxproj"
# Altera somente o identificador do Runner; RunnerTests continua herdando $(PRODUCT_BUNDLE_IDENTIFIER).
perl -0pi -e 's/PRODUCT_BUNDLE_IDENTIFIER = (?!\$\()[^;]+;/PRODUCT_BUNDLE_IDENTIFIER = '"$BUNDLE_ID"';/g' "$PBX"
perl -0pi -e 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g' "$PBX"
if [[ -n "$TEAM_ID" ]]; then
  if grep -q 'DEVELOPMENT_TEAM = ' "$PBX"; then
    perl -0pi -e 's/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = '"$TEAM_ID"';/g' "$PBX"
  else
    perl -0pi -e 's/(CODE_SIGN_STYLE = Automatic;)/$1\n\t\t\t\tDEVELOPMENT_TEAM = '"$TEAM_ID"';/g' "$PBX"
  fi
fi

PLIST="ios/Runner/Info.plist"
plist_set(){
  local key="$1" type="$2" value="$3"
  /usr/libexec/PlistBuddy -c "Set :$key $value" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$PLIST"
}
plist_set CFBundleDisplayName string "$APP_NAME"
plist_set CFBundleName string "$APP_NAME"
plist_set NSFaceIDUsageDescription string "Use o Face ID para entrar com seguranca no aplicativo."
plist_set NSCameraUsageDescription string "Permite tirar uma foto para o perfil do cliente."
plist_set NSPhotoLibraryUsageDescription string "Permite escolher uma foto para o perfil do cliente."

# O ambiente atual da Soft ainda pode usar HTTP/DDNS para testes. Em producao, prefira HTTPS e remova esta liberacao.
if [[ "$API_URL" == http://* ]]; then
  /usr/libexec/PlistBuddy -c 'Delete :NSAppTransportSecurity' "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' "$PLIST"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true' "$PLIST"
fi

printf '\n[5/9] Icone iOS\n'
ICON_SRC="tooling/.ios_sync/icon_source"
ICONSET="ios/Runner/Assets.xcassets/AppIcon.appiconset"
if [[ -f "$ICON_SRC" ]]; then
  mkdir -p "$ICONSET"
  make_icon(){ local name="$1" px="$2"; sips -s format png -z "$px" "$px" "$ICON_SRC" --out "$ICONSET/$name" >/dev/null; }
  make_icon Icon-App-20x20@1x.png 20
  make_icon Icon-App-20x20@2x.png 40
  make_icon Icon-App-20x20@3x.png 60
  make_icon Icon-App-29x29@1x.png 29
  make_icon Icon-App-29x29@2x.png 58
  make_icon Icon-App-29x29@3x.png 87
  make_icon Icon-App-40x40@1x.png 40
  make_icon Icon-App-40x40@2x.png 80
  make_icon Icon-App-40x40@3x.png 120
  make_icon Icon-App-60x60@2x.png 120
  make_icon Icon-App-60x60@3x.png 180
  make_icon Icon-App-76x76@1x.png 76
  make_icon Icon-App-76x76@2x.png 152
  make_icon Icon-App-83.5x83.5@2x.png 167
  make_icon Icon-App-1024x1024@1x.png 1024
  cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images" : [
    {"idiom":"iphone","size":"20x20","scale":"2x","filename":"Icon-App-20x20@2x.png"},
    {"idiom":"iphone","size":"20x20","scale":"3x","filename":"Icon-App-20x20@3x.png"},
    {"idiom":"iphone","size":"29x29","scale":"2x","filename":"Icon-App-29x29@2x.png"},
    {"idiom":"iphone","size":"29x29","scale":"3x","filename":"Icon-App-29x29@3x.png"},
    {"idiom":"iphone","size":"40x40","scale":"2x","filename":"Icon-App-40x40@2x.png"},
    {"idiom":"iphone","size":"40x40","scale":"3x","filename":"Icon-App-40x40@3x.png"},
    {"idiom":"iphone","size":"60x60","scale":"2x","filename":"Icon-App-60x60@2x.png"},
    {"idiom":"iphone","size":"60x60","scale":"3x","filename":"Icon-App-60x60@3x.png"},
    {"idiom":"ipad","size":"20x20","scale":"1x","filename":"Icon-App-20x20@1x.png"},
    {"idiom":"ipad","size":"20x20","scale":"2x","filename":"Icon-App-20x20@2x.png"},
    {"idiom":"ipad","size":"29x29","scale":"1x","filename":"Icon-App-29x29@1x.png"},
    {"idiom":"ipad","size":"29x29","scale":"2x","filename":"Icon-App-29x29@2x.png"},
    {"idiom":"ipad","size":"40x40","scale":"1x","filename":"Icon-App-40x40@1x.png"},
    {"idiom":"ipad","size":"40x40","scale":"2x","filename":"Icon-App-40x40@2x.png"},
    {"idiom":"ipad","size":"76x76","scale":"1x","filename":"Icon-App-76x76@1x.png"},
    {"idiom":"ipad","size":"76x76","scale":"2x","filename":"Icon-App-76x76@2x.png"},
    {"idiom":"ipad","size":"83.5x83.5","scale":"2x","filename":"Icon-App-83.5x83.5@2x.png"},
    {"idiom":"ios-marketing","size":"1024x1024","scale":"1x","filename":"Icon-App-1024x1024@1x.png"}
  ],
  "info" : {"author":"xcode","version":1}
}
JSON
else
  echo "Aviso: bootstrap nao forneceu icone iOS/logo; mantido o icone padrao do Flutter."
fi

printf '\n[6/9] Dependencias Flutter\n'
flutter pub get

printf '\n[7/9] CocoaPods\n'
if command -v pod >/dev/null 2>&1; then
  (cd ios && pod install)
else
  echo "CocoaPods nao encontrado. O Flutter pode orientar a instalacao no primeiro build."
fi

printf '\n[8/9] Analise Dart\n'
flutter analyze || { echo "flutter analyze encontrou problemas; revise antes de publicar."; exit 1; }

printf '\n[9/9] Pronto\n'
echo "App:       $APP_NAME"
echo "Bundle ID: $BUNDLE_ID"
echo "API:       $API_URL"
echo "Versao:    1.6.20+178"
echo
if [[ -n "$TEAM_ID" ]]; then
  echo "Apple Team: $TEAM_ID"
else
  echo "Para iPhone fisico: abra ios/Runner.xcworkspace e selecione seu Team em Signing & Capabilities."
fi
echo
printf 'Rodar no simulador/iPhone conectado:\n  ./tooling/run_ios.sh\n\n'
printf 'Abrir no Xcode:\n  ./tooling/open_xcode.sh\n\n'
printf 'Gerar IPA release:\n  ./tooling/build_ipa.sh\n'

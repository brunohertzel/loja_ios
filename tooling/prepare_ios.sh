


    
  
    "$PLIST"

  /usr/libexec/PlistBuddy \
    -c 'Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true' \
    "$PLIST"
fi

printf '\n[5/9] Icone iOS\n'

ICON_SRC="tooling/.ios_sync/icon_source"
ICONSET="ios/Runner/Assets.xcassets/AppIcon.appiconset"

if [[ -f "$ICON_SRC" ]]; then
  mkdir -p "$ICONSET"

  make_icon(){
    local name="$1"
    local px="$2"

    sips \
      -s format png \
      -z "$px" "$px" \
      "$ICON_SRC" \
      --out "$ICONSET/$name" >/dev/null
  }

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
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

else
  echo "Aviso: bootstrap nao forneceu icone iOS/logo; mantido o icone padrao do Flutter."
fi

printf '\n[6/9] Dependencias Flutter\n'
flutter pub get

printf '\n[7/9] CocoaPods\n'

if command -v pod >/dev/null 2>&1; then
  rm -rf ios/Pods
  rm -f ios/Podfile.lock

  (
    cd ios

    echo "Podfile usado pelo CocoaPods:"
    grep "platform :ios" Podfile || true

    pod install --repo-update
  )
else
  echo "CocoaPods nao encontrado. O Flutter pode orientar a instalacao no primeiro build."
fi

printf '\n[8/9] Analise Dart\n'

# No Codemagic, warnings e infos do analyzer não devem interromper o build.
# O build só deve parar se houver erro real de análise.
flutter analyze --no-fatal-infos --no-fatal-warnings

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

printf 'Rodar no simulador/iPhone conectado:\n'
printf '  ./tooling/run_ios.sh\n\n'


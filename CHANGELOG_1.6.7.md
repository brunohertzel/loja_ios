# Soft Ecommerce Mobile Android 1.6.7

Correção de build e encoding, sem alteração no módulo Mobile do servidor.

## Android
- Android Gradle Plugin: 8.9.2
- Gradle wrapper: 8.11.1
- Kotlin permanece 2.1.20
- JDK requerido: 17 ou superior compatível com o Flutter instalado

## UTF-8
O `sync_android_branding.ps1` não depende mais da interpretação automática de charset do Windows PowerShell 5.1.
O bootstrap é baixado como bytes e decodificado explicitamente como UTF-8.
O cache local e o arquivo Dart gerado também usam UTF-8 explícito.

## Build comercial
```powershell
.\tooling\sync_android_branding.cmd URL_DA_API_MOBILE
flutter clean
flutter pub get
flutter build apk --release --dart-define=SOFT_API_BASE_URL=URL_DA_API_MOBILE
```

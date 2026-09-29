param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "mobile_app_config.json")
)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $Root
try {
    & (Join-Path $PSScriptRoot "apply_build_config.ps1") -ConfigFile $ConfigFile
    flutter pub get
    flutter build apk --release
    Write-Host "APK gerado em build/app/outputs/flutter-apk/" -ForegroundColor Green
} finally { Pop-Location }

param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "mobile_app_config.json")
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not (Test-Path $ConfigFile)) { throw "Arquivo local nao encontrado: $ConfigFile" }
$ConfigFile = (Resolve-Path $ConfigFile).Path
$LocalConfigJson = [System.IO.File]::ReadAllText($ConfigFile, [System.Text.Encoding]::UTF8)
$LocalConfig = $LocalConfigJson | ConvertFrom-Json
$PackageId = ([string]$LocalConfig.android_package_id).Trim()
if ([string]::IsNullOrWhiteSpace($PackageId)) { $PackageId = "br.com.softsistemas.soft_ecommerce_mobile" }
$AppName = ([string]$LocalConfig.app_name).Trim()
if ([string]::IsNullOrWhiteSpace($AppName)) { $AppName = "Loja" }
Push-Location $Root
try {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "Flutter nao encontrado no PATH. Abra um terminal onde 'flutter --version' funcione."
    }

    Write-Host "[1/7] Flutter instalado" -ForegroundColor Cyan
    flutter --version

    Write-Host "[2/7] Gerando scaffolding Android com a versao do seu Flutter" -ForegroundColor Cyan
    $Backup = Join-Path $env:TEMP ("soft_mobile_" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    foreach ($item in @("lib", "tooling", "docs", "test")) {
        $src = Join-Path $Root $item
        if (Test-Path $src) { Copy-Item $src (Join-Path $Backup $item) -Recurse -Force }
    }
    foreach ($file in @("pubspec.yaml", "analysis_options.yaml", "README.md", "CHANGELOG.md", ".gitignore")) {
        $src = Join-Path $Root $file
        if (Test-Path $src) { Copy-Item $src (Join-Path $Backup $file) -Force }
    }

    flutter create . --platforms=android --org br.com.softsistemas --project-name soft_ecommerce_mobile

    foreach ($item in @("lib", "tooling", "docs", "test")) {
        $dst = Join-Path $Root $item
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        $src = Join-Path $Backup $item
        if (Test-Path $src) { Copy-Item $src $dst -Recurse -Force }
    }
    foreach ($file in @("pubspec.yaml", "analysis_options.yaml", "README.md", "CHANGELOG.md", ".gitignore")) {
        $src = Join-Path $Backup $file
        if (Test-Path $src) { Copy-Item $src (Join-Path $Root $file) -Force }
    }
    Remove-Item $Backup -Recurse -Force

    Write-Host "[3/7] Configurando package/app name" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "set_branding.ps1") -PackageId $PackageId -AppName $AppName

    Write-Host "[4/7] Habilitando biometria e Internet" -ForegroundColor Cyan
    $manifest = Join-Path $Root "android/app/src/main/AndroidManifest.xml"
    $m = Get-Content $manifest -Raw
    if ($m -notmatch 'android.permission.USE_BIOMETRIC') {
        $m = $m -replace '<manifest([^>]*)>', ('<manifest$1>' + [Environment]::NewLine + '    <uses-permission android:name="android.permission.USE_BIOMETRIC" />')
    }
    if ($m -notmatch 'android.permission.INTERNET') {
        $m = $m -replace '<manifest([^>]*)>', ('<manifest$1>' + [Environment]::NewLine + '    <uses-permission android:name="android.permission.INTERNET" />')
    }
    if ($m -notmatch 'com.google.android.gms.wallet.api.enabled') {
        $m = $m -replace '<meta-data android:name="flutterEmbedding" android:value="2" />', ('<meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true" />' + [Environment]::NewLine + '        <meta-data android:name="flutterEmbedding" android:value="2" />')
    }
    $m = $m -replace 'android:allowBackup="true"', 'android:allowBackup="false"'
    Set-Content -Encoding UTF8 $manifest $m

    Write-Host "[5/7] Ajustando minSdk 24 + AppCompat" -ForegroundColor Cyan
    $gradleKts = Join-Path $Root "android/app/build.gradle.kts"
    if (Test-Path $gradleKts) {
        $g = Get-Content $gradleKts -Raw
        $g = $g -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24'
        if ($g -notmatch 'androidx\.appcompat:appcompat') {
            $g += @'

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
}
'@
        }
        Set-Content -Encoding UTF8 $gradleKts $g
    } else {
        $gradle = Join-Path $Root "android/app/build.gradle"
        if (Test-Path $gradle) {
            $g = Get-Content $gradle -Raw
            $g = $g -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24'
            if ($g -notmatch 'androidx\.appcompat:appcompat') {
                $g += @'

dependencies {
    implementation 'androidx.appcompat:appcompat:1.7.0'
}
'@
            }
            Set-Content -Encoding UTF8 $gradle $g
        }
    }

    Write-Host "[6/7] Ajustando biometria nativa e debug local" -ForegroundColor Cyan
    foreach ($styles in @(
        (Join-Path $Root "android/app/src/main/res/values/styles.xml"),
        (Join-Path $Root "android/app/src/main/res/values-night/styles.xml")
    )) {
        if (Test-Path $styles) {
            $s = Get-Content $styles -Raw
            $s = [regex]::Replace($s, '<style name="LaunchTheme"[^>]*>', '<style name="LaunchTheme" parent="Theme.AppCompat.DayNight.NoActionBar">')
            $s = [regex]::Replace($s, '<style name="NormalTheme"[^>]*>', '<style name="NormalTheme" parent="Theme.AppCompat.DayNight.NoActionBar">')
            Set-Content -Encoding UTF8 $styles $s
        }
    }

    $debugManifest = Join-Path $Root "android/app/src/debug/AndroidManifest.xml"
    New-Item -ItemType Directory -Force -Path (Split-Path $debugManifest) | Out-Null
    @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <!-- Somente debug: permite testar contra XAMPP/http local. Release permanece HTTPS-only. -->
    <application
        android:usesCleartextTraffic="true"
        tools:replace="android:usesCleartextTraffic" />
</manifest>
'@ | Set-Content -Encoding UTF8 $debugManifest

    Write-Host "[6a/7] Atualizando toolchain Android compativel com dependencias atuais" -ForegroundColor Cyan
    foreach ($settings in @(
        (Join-Path $Root "android/settings.gradle.kts"),
        (Join-Path $Root "android/settings.gradle")
    )) {
        if (Test-Path $settings) {
            $sg = Get-Content $settings -Raw
            $sg = [regex]::Replace($sg, 'id\("com\.android\.application"\) version "[^"]+"', 'id("com.android.application") version "8.9.2"')
            $sg = [regex]::Replace($sg, 'id\("org\.jetbrains\.kotlin\.android"\) version "[^"]+"', 'id("org.jetbrains.kotlin.android") version "2.1.20"')
            $sg = [regex]::Replace($sg, 'id\s+"com\.android\.application"\s+version\s+"[^"]+"', 'id "com.android.application" version "8.9.2"')
            $sg = [regex]::Replace($sg, 'id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+"[^"]+"', 'id "org.jetbrains.kotlin.android" version "2.1.20"')
            Set-Content -Encoding UTF8 $settings $sg
        }
    }
    $wrapper = Join-Path $Root "android/gradle/wrapper/gradle-wrapper.properties"
    if (Test-Path $wrapper) {
        $wg = Get-Content $wrapper -Raw
        $wg = [regex]::Replace($wg, 'gradle-[0-9.]+-(all|bin)\.zip', 'gradle-8.11.1-all.zip')
        Set-Content -Encoding UTF8 $wrapper $wg
    }

    Write-Host "[6b/7] Ajustando MainActivity para FlutterFragmentActivity" -ForegroundColor Cyan
    $packagePath = $PackageId.Replace('.', '/')
    Get-ChildItem (Join-Path $Root "android/app/src/main/kotlin") -Filter MainActivity.kt -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
    $mainActivity = Join-Path $Root ("android/app/src/main/kotlin/" + $packagePath + "/MainActivity.kt")
    New-Item -ItemType Directory -Force -Path (Split-Path $mainActivity) | Out-Null
    @"
package $PackageId

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
"@ | Set-Content -Encoding UTF8 $mainActivity

    Write-Host "[7/7] Configuracao local + dependencias" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "apply_local_config.ps1") -ConfigFile $ConfigFile
    flutter pub get

    Write-Host "" 
    Write-Host "Projeto Android preparado." -ForegroundColor Green
    Write-Host "Teste com:" -ForegroundColor Yellow
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\tooling\run_android.ps1'
}
finally {
    Pop-Location
}

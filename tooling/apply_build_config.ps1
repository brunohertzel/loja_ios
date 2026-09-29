param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot 'mobile_app_config.json')
)

$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {}

function Write-SoftUtf8NoBom([string]$Path, [string]$Content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    if (Test-Path $Path) {
        $existing = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        if ($existing -ceq $Content) {
            return $false
        }
    }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    return $true
}
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path $ConfigFile)) { throw "Arquivo de configuracao do build nao encontrado: $ConfigFile" }
$ConfigFile = (Resolve-Path $ConfigFile).Path
$cfgJson = [System.IO.File]::ReadAllText($ConfigFile, [System.Text.Encoding]::UTF8)
$cfg = $cfgJson | ConvertFrom-Json

function RequiredText([object]$value, [string]$name) {
    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) { throw "Campo obrigatorio ausente: $name" }
    return $text.Trim()
}
function DartText([object]$value) {
    $s = [string]$value
    $s = $s.Replace('\','\\').Replace("'","\'").Replace("`r",'\r').Replace("`n",'\n')
    return $s
}
function SoftBool([object]$value, [bool]$fallback=$false) {
    if ($null -eq $value) { return $fallback }
    if ($value -is [bool]) { return [bool]$value }
    $t=([string]$value).Trim().ToLowerInvariant()
    if($t -in @('1','true','yes','sim','on')){return $true}
    if($t -in @('0','false','no','nao','não','off')){return $false}
    return $fallback
}
function BoolText([object]$value) { if (SoftBool $value $false) { return 'true' } return 'false' }

if (-not (SoftBool $cfg.branding_synced $false)) {
    throw "Branding deste cliente ainda nao foi sincronizado. Execute: .\tooling\sync_android_branding.cmd URL_DA_API_MOBILE"
}

$appName = RequiredText $cfg.app_name 'app_name'
$apiBaseUrl = (RequiredText $cfg.api_base_url 'api_base_url').TrimEnd('/')
$packageId = RequiredText $cfg.android_package_id 'android_package_id'
if ($packageId -notmatch '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$') { throw "android_package_id invalido: $packageId" }
$theme = ([string]$cfg.theme_default).ToUpperInvariant(); if ($theme -notin @('SYSTEM','LIGHT','DARK')) { $theme = 'SYSTEM' }
$primary = [string]$cfg.primary_color; if ($primary -notmatch '^#[0-9A-Fa-f]{6}$') { $primary = '#1A73E8' }
$secondary = [string]$cfg.secondary_color; if ($secondary -notmatch '^#[0-9A-Fa-f]{6}$') { $secondary = '#202124' }
$logoUrl = [string]$cfg.logo_url
$splashUrl = [string]$cfg.splash_url
$iconUrl = [string]$cfg.icon_android_url
$googleWebClientId = [string]$cfg.google_web_client_id
$gp = $cfg.google_pay
$gpayEnabled = if ($null -ne $gp) { SoftBool $gp.enabled $false } else { $false }
$gpayEnv = if ($null -ne $gp) { ([string]$gp.environment).ToUpperInvariant() } else { 'TEST' }; if ($gpayEnv -notin @('TEST','PRODUCTION')) { $gpayEnv = 'TEST' }
$gpayMerchantId = if ($null -ne $gp) { [string]$gp.merchant_id } else { '' }
$gpayMerchantName = if ($null -ne $gp) { [string]$gp.merchant_name } else { '' }; if ([string]::IsNullOrWhiteSpace($gpayMerchantName)) { $gpayMerchantName = $appName }

$release=$cfg.release
$releaseModule='';$releaseVersion='';$releaseBuild='';$releaseMin='';$releaseForce=$false;$releaseStore=''
if($null -ne $release){
    $releaseModule=[string]$release.module_version
    $releaseVersion=([string]$release.current_version).Trim()
    $releaseBuild=([string]$release.current_build).Trim()
    $releaseMin=[string]$release.min_version
    $releaseForce=SoftBool $release.force_update $false
    $releaseStore=[string]$release.store_url
}

# Se a versao/build do release estiverem cadastrados no modulo, eles viram versionName/versionCode do APK.
if ($releaseVersion -match '^\d+\.\d+\.\d+([-.][0-9A-Za-z.-]+)?$' -and $releaseBuild -match '^\d+$' -and [int64]$releaseBuild -gt 0) {
    $pubspec=Join-Path $Root 'pubspec.yaml'
    if(Test-Path $pubspec){
        $p=[System.IO.File]::ReadAllText($pubspec, [System.Text.Encoding]::UTF8)
        $p=[regex]::Replace($p,'(?m)^version:\s*.*$',("version: {0}+{1}" -f $releaseVersion,$releaseBuild),1)
        Write-SoftUtf8NoBom $pubspec $p
    }
}

$buildGeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')

$dart = @"
// GENERATED FILE - Soft Ecommerce Mobile 1.6.19
// Source: API do cliente via tooling/sync_android_branding.cmd
// Nao edite manualmente. Sincronize novamente antes de cada release.
class GeneratedAppConfig {
  static const int schema = 3;
  static const String appName = '$(DartText $appName)';
  static const String apiBaseUrl = '$(DartText $apiBaseUrl)';
  static const String androidPackageId = '$(DartText $packageId)';
  static const String themeDefault = '$(DartText $theme)';
  static const String primaryColor = '$(DartText $primary)';
  static const String secondaryColor = '$(DartText $secondary)';
  static const String logoUrl = '$(DartText $logoUrl)';
  static const String splashUrl = '$(DartText $splashUrl)';
  static const String iconAndroidUrl = '$(DartText $iconUrl)';
  static const String googleWebClientId = '$(DartText $googleWebClientId)';
  static const bool googlePayEnabled = $(BoolText $gpayEnabled);
  static const String googlePayEnvironment = '$(DartText $gpayEnv)';
  static const String googlePayMerchantId = '$(DartText $gpayMerchantId)';
  static const String googlePayMerchantName = '$(DartText $gpayMerchantName)';
  static const String releaseModuleVersion = '$(DartText $releaseModule)';
  static const String releaseCurrentVersion = '$(DartText $releaseVersion)';
  static const String releaseCurrentBuild = '$(DartText $releaseBuild)';
  static const String releaseMinVersion = '$(DartText $releaseMin)';
  static const bool releaseForceUpdate = $(BoolText $releaseForce);
  static const String releaseStoreUrl = '$(DartText $releaseStore)';
  static const String buildGeneratedAt = '$(DartText $buildGeneratedAt)';
}
"@
$generated = Join-Path $Root 'lib/core/config/generated_app_config.dart'
New-Item -ItemType Directory -Force -Path (Split-Path $generated) | Out-Null
Write-SoftUtf8NoBom $generated $dart

# MainActivity acompanha o package do cliente.
$kotlinRoot = Join-Path $Root 'android/app/src/main/kotlin'
$packagePath = $packageId.Replace('.', '/')
$mainActivity = Join-Path $Root ('android/app/src/main/kotlin/' + $packagePath + '/MainActivity.kt')
New-Item -ItemType Directory -Force -Path (Split-Path $mainActivity) | Out-Null

if (Test-Path $kotlinRoot) {
    Get-ChildItem $kotlinRoot -Filter MainActivity.kt -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.FullName -ne $mainActivity) {
            Remove-Item $_.FullName -Force
        }
    }
}

$mainActivityContent = @"
package $packageId
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity()
"@
Write-SoftUtf8NoBom $mainActivity $mainActivityContent | Out-Null

# HTTP legado/local e liberado apenas quando a API sincronizada usa http://.
$manifest = Join-Path $Root 'android/app/src/main/AndroidManifest.xml'
if (Test-Path $manifest) {
    $m = [System.IO.File]::ReadAllText($manifest, [System.Text.Encoding]::UTF8)
    $clear = if ($apiBaseUrl.ToLowerInvariant().StartsWith('http://')) { 'true' } else { 'false' }
    if ($m -match 'android:usesCleartextTraffic=') { $m = [regex]::Replace($m, 'android:usesCleartextTraffic="[^"]*"', ('android:usesCleartextTraffic="' + $clear + '"')) }
    Write-SoftUtf8NoBom $manifest $m
}

# Gera launcher/adaptive icon e splash com os assets do cliente sincronizado.
& (Join-Path $PSScriptRoot 'sync_android_branding.ps1') -ConfigFile $ConfigFile -AssetsOnly

Write-Host "Configuracao do cliente aplicada: $appName / $packageId / $apiBaseUrl" -ForegroundColor Green

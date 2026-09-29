param(
    [string]$ApiBaseUrl = '',
    [string]$ConfigFile = '',
    [switch]$AssetsOnly
)

$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {}
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$DefaultConfigFile = Join-Path $PSScriptRoot 'mobile_app_config.json'

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

function Get-SoftText([object]$value, [string]$fallback = '') {
    if ($null -eq $value) { return $fallback }
    $text = ([string]$value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $fallback }
    return $text
}

function Get-SoftBool([object]$value, [bool]$fallback = $false) {
    if ($null -eq $value) { return $fallback }
    if ($value -is [bool]) { return [bool]$value }
    $text = ([string]$value).Trim().ToLowerInvariant()
    if ($text -in @('1','true','yes','sim','on')) { return $true }
    if ($text -in @('0','false','no','nao','não','off')) { return $false }
    return $fallback
}

function Save-SquarePng {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)][int]$Size,
        [double]$ContentRatio = 0.72
    )
    $img = [System.Drawing.Image]::FromFile($Source)
    try {
        $bmp = New-Object System.Drawing.Bitmap($Size,$Size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $g=[System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.Clear([System.Drawing.Color]::Transparent)
                $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $max=[Math]::Max(1,[int]($Size*$ContentRatio))
                $scale=[Math]::Min($max/$img.Width,$max/$img.Height)
                $w=[Math]::Max(1,[int][Math]::Round($img.Width*$scale))
                $h=[Math]::Max(1,[int][Math]::Round($img.Height*$scale))
                $g.DrawImage($img,[int](($Size-$w)/2),[int](($Size-$h)/2),$w,$h)
            } finally { $g.Dispose() }
            New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
            $bmp.Save($Destination,[System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $bmp.Dispose() }
    } finally { $img.Dispose() }
}

function Apply-SoftAssets([string]$LocalConfigFile) {
    if (-not (Test-Path $LocalConfigFile)) { throw "Arquivo local nao encontrado: $LocalConfigFile" }
    $LocalConfigFile = (Resolve-Path $LocalConfigFile).Path
    $cfgJson = [System.IO.File]::ReadAllText($LocalConfigFile, [System.Text.Encoding]::UTF8)
    $cfg = $cfgJson | ConvertFrom-Json

    $appName = Get-SoftText $cfg.app_name 'Loja'
    $packageId = Get-SoftText $cfg.android_package_id ''
    if ([string]::IsNullOrWhiteSpace($packageId)) { throw 'Package ID Android nao informado no modulo Mobile.' }
    $primary = Get-SoftText $cfg.primary_color '#FFFFFF'
    if ($primary -notmatch '^#[0-9A-Fa-f]{6}$') { $primary = '#FFFFFF' }
    $iconUrl = Get-SoftText $cfg.icon_android_url ''
    if ([string]::IsNullOrWhiteSpace($iconUrl)) { $iconUrl = Get-SoftText $cfg.logo_url '' }
    if ([string]::IsNullOrWhiteSpace($iconUrl)) { $iconUrl = Get-SoftText $cfg.splash_url '' }

    if ([string]::IsNullOrWhiteSpace($iconUrl)) {
        $manifest = Join-Path $Root 'android/app/src/main/AndroidManifest.xml'
        if (Test-Path $manifest) {
            $m = Get-Content $manifest -Raw
            $m = [regex]::Replace($m, 'android:icon="[^"]*"', 'android:icon="@drawable/soft_default_launcher"')
            $m = [regex]::Replace($m, 'android:roundIcon="[^"]*"', 'android:roundIcon="@drawable/soft_default_launcher"')
            Set-Content -Encoding UTF8 $manifest $m
        }
        Write-Warning 'Nenhum Icone Android/Logo/Splash foi configurado no modulo Mobile. Mantendo icone padrao local.'
        return
    }

    Write-Host "Baixando identidade visual de $iconUrl ..." -ForegroundColor Cyan
    $tmp = Join-Path $env:TEMP ('soft_mobile_branding_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $download = Join-Path $tmp 'source'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $iconUrl -OutFile $download -TimeoutSec 30
        Add-Type -AssemblyName System.Drawing

        Save-SquarePng -Source $download -Destination (Join-Path $Root 'android/app/src/main/res/drawable-nodpi/soft_launch_logo.png') -Size 432 -ContentRatio 0.68
        Save-SquarePng -Source $download -Destination (Join-Path $Root 'android/app/src/main/res/drawable-nodpi/soft_launcher_foreground.png') -Size 432 -ContentRatio 0.62
        $densities=@{'mipmap-mdpi'=48;'mipmap-hdpi'=72;'mipmap-xhdpi'=96;'mipmap-xxhdpi'=144;'mipmap-xxxhdpi'=192}
        foreach($entry in $densities.GetEnumerator()){
            $dir=Join-Path $Root ('android/app/src/main/res/'+$entry.Key)
            Save-SquarePng -Source $download -Destination (Join-Path $dir 'ic_launcher.png') -Size ([int]$entry.Value) -ContentRatio 0.78
            Save-SquarePng -Source $download -Destination (Join-Path $dir 'ic_launcher_round.png') -Size ([int]$entry.Value) -ContentRatio 0.72
        }

        $adaptiveDir=Join-Path $Root 'android/app/src/main/res/mipmap-anydpi-v26'
        New-Item -ItemType Directory -Force -Path $adaptiveDir|Out-Null
        $adaptiveXml=@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/soft_launcher_background" />
    <foreground android:drawable="@drawable/soft_launcher_foreground" />
</adaptive-icon>
'@
        Set-Content -Encoding UTF8 (Join-Path $adaptiveDir 'ic_launcher.xml') $adaptiveXml
        Set-Content -Encoding UTF8 (Join-Path $adaptiveDir 'ic_launcher_round.xml') $adaptiveXml

        $valuesDir=Join-Path $Root 'android/app/src/main/res/values'
        New-Item -ItemType Directory -Force -Path $valuesDir|Out-Null
        @"
<?xml version="1.0" encoding="utf-8"?>
<resources><color name="soft_launcher_background">$primary</color></resources>
"@ | Set-Content -Encoding UTF8 (Join-Path $valuesDir 'soft_launcher_colors.xml')

        foreach($styleFile in @((Join-Path $Root 'android/app/src/main/res/values-v31/styles.xml'),(Join-Path $Root 'android/app/src/main/res/values-night-v31/styles.xml'))){
            if(Test-Path $styleFile){
                $st=Get-Content $styleFile -Raw
                $st=$st.Replace('@drawable/soft_splash_transparent','@drawable/soft_launch_logo')
                Set-Content -Encoding UTF8 $styleFile $st
            }
        }

        $launchXml=@'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
    <item><bitmap android:gravity="center" android:src="@drawable/soft_launch_logo" /></item>
</layer-list>
'@
        Set-Content -Encoding UTF8 (Join-Path $Root 'android/app/src/main/res/drawable/launch_background.xml') $launchXml
        Set-Content -Encoding UTF8 (Join-Path $Root 'android/app/src/main/res/drawable-v21/launch_background.xml') $launchXml

        $manifest = Join-Path $Root 'android/app/src/main/AndroidManifest.xml'
        if (Test-Path $manifest) {
            $m = Get-Content $manifest -Raw
            $m = [regex]::Replace($m, 'android:icon="[^"]*"', 'android:icon="@mipmap/ic_launcher"')
            $m = [regex]::Replace($m, 'android:roundIcon="[^"]*"', 'android:roundIcon="@mipmap/ic_launcher_round"')
            Set-Content -Encoding UTF8 $manifest $m
        }
        Write-Host "Branding Android aplicado: $appName / $packageId" -ForegroundColor Green
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

if ($AssetsOnly) {
    if ([string]::IsNullOrWhiteSpace($ConfigFile)) { $ConfigFile = $DefaultConfigFile }
    Apply-SoftAssets $ConfigFile
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd('/')
    if ($ApiBaseUrl -notmatch '^https?://') { throw "URL da API invalida: $ApiBaseUrl" }
    $BootstrapUrl = "$ApiBaseUrl/bootstrap.php"
    Write-Host "Lendo release e personalizacao em $BootstrapUrl ..." -ForegroundColor Cyan

    $headers = @{
        'X-Soft-Platform' = 'ANDROID'
        'X-Soft-App-Version' = '1.6.19'
        'X-Soft-Build' = '175'
    }
    try {
        # Windows PowerShell 5.1 pode interpretar JSON UTF-8 sem charset usando a
        # pagina de codigo local. Lemos os bytes e decodificamos explicitamente
        # como UTF-8 para preservar acentos em nome da loja, produtos e branding.
        $request = [System.Net.HttpWebRequest]::Create($BootstrapUrl)
        $request.Method = 'GET'
        $request.Timeout = 25000
        $request.ReadWriteTimeout = 25000
        $request.Accept = 'application/json'
        foreach ($entry in $headers.GetEnumerator()) {
            $request.Headers[$entry.Key] = [string]$entry.Value
        }
        $response = $request.GetResponse()
        try {
            $stream = $response.GetResponseStream()
            try {
                $memory = New-Object System.IO.MemoryStream
                try {
                    $stream.CopyTo($memory)
                    $bytes = $memory.ToArray()
                } finally {
                    $memory.Dispose()
                }
            } finally {
                if ($null -ne $stream) { $stream.Dispose() }
            }
        } finally {
            $response.Dispose()
        }

        $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
        $jsonText = $utf8Strict.GetString($bytes)
        $boot = $jsonText | ConvertFrom-Json
    } catch {
        throw "Nao foi possivel consultar/decodificar o bootstrap Mobile como UTF-8: $($_.Exception.Message)"
    }
    if (-not $boot -or -not $boot.app) { throw 'Bootstrap Mobile nao retornou o bloco app.' }
    if ($null -ne $boot.platform_allowed -and -not (Get-SoftBool $boot.platform_allowed $false)) {
        throw 'Android nao esta liberado para este cliente/licenca no modulo Mobile.'
    }

    $packageId = Get-SoftText $boot.app.package_id ''
    if ([string]::IsNullOrWhiteSpace($packageId)) {
        throw 'Package ID Android vazio. Configure em Admin > Mobile > Android antes de compilar.'
    }
    $appName = Get-SoftText $boot.app.name ''
    if ([string]::IsNullOrWhiteSpace($appName)) { throw 'Nome do app vazio. Configure em Admin > Mobile > Geral.' }

    $theme = (Get-SoftText $boot.app.theme_default 'SYSTEM').ToUpperInvariant()
    if ($theme -notin @('SYSTEM','LIGHT','DARK')) { $theme='SYSTEM' }
    $primary = Get-SoftText $boot.app.primary_color '#1A73E8'
    $secondary = Get-SoftText $boot.app.secondary_color '#202124'

    $gpayEnabled = $false
    $gpayEnv = 'TEST'
    $gpayMerchantId = ''
    $gpayMerchantName = $appName
    if ($boot.payments) {
        $gpayEnabled = Get-SoftBool $boot.payments.google_pay $false
        $gpayEnv = (Get-SoftText $boot.payments.google_pay_environment 'TEST').ToUpperInvariant()
        if ($gpayEnv -notin @('TEST','PRODUCTION')) { $gpayEnv='TEST' }
        $gpayMerchantId = Get-SoftText $boot.payments.google_pay_merchant_id ''
        $gpayMerchantName = Get-SoftText $boot.payments.google_pay_merchant_name $appName
    }

    $googleWebClientId = ''
    if ($boot.security) { $googleWebClientId = Get-SoftText $boot.security.google_web_client_id '' }

    $cfg = [ordered]@{
        schema = 3
        branding_synced = $true
        source_api_base_url = $ApiBaseUrl
        synced_at = (Get-Date).ToString('o')
        app_name = $appName
        api_base_url = $ApiBaseUrl
        android_package_id = $packageId
        theme_default = $theme
        primary_color = $primary
        secondary_color = $secondary
        logo_url = Get-SoftText $boot.app.logo_url ''
        splash_url = Get-SoftText $boot.app.splash_url ''
        icon_android_url = Get-SoftText $boot.app.icon_android_url ''
        google_web_client_id = $googleWebClientId
        google_pay = [ordered]@{
            enabled = $gpayEnabled
            environment = $gpayEnv
            merchant_id = $gpayMerchantId
            merchant_name = $gpayMerchantName
        }
        release = [ordered]@{
            module_version = Get-SoftText $boot.module_version ''
            current_version = Get-SoftText $boot.app.current_version ''
            current_build = Get-SoftText $boot.app.current_build ''
            min_version = Get-SoftText $boot.app.min_version ''
            force_update = Get-SoftBool $boot.app.force_update $false
            store_url = Get-SoftText $boot.app.store_url ''
        }
    }

    $jsonConfig = $cfg | ConvertTo-Json -Depth 8
    Write-SoftUtf8NoBom $DefaultConfigFile $jsonConfig
    Write-Host "Configuracao do cliente salva em $DefaultConfigFile" -ForegroundColor DarkGray
    & (Join-Path $PSScriptRoot 'apply_local_config.ps1') -ConfigFile $DefaultConfigFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host ''
    Write-Host 'Release lido do cliente:' -ForegroundColor Cyan
    Write-Host ("  App:       {0}" -f $appName)
    Write-Host ("  Package:   {0}" -f $packageId)
    Write-Host ("  Versao:    {0}" -f (Get-SoftText $boot.app.current_version '(nao informada)'))
    Write-Host ("  Build:     {0}" -f (Get-SoftText $boot.app.current_build '(nao informado)'))
    Write-Host ("  Minima:    {0}" -f (Get-SoftText $boot.app.min_version '(nao informada)'))
    Write-Host ("  Forcar:    {0}" -f (Get-SoftBool $boot.app.force_update $false))
    Write-Host ("  Modulo:    {0}" -f (Get-SoftText $boot.module_version '(nao informado)'))
    Write-Host ("  API:       {0}" -f $ApiBaseUrl)
    Write-Host 'Sincronizacao concluida. Agora execute flutter clean/pub get/build.' -ForegroundColor Green
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ConfigFile)) { $ConfigFile = $DefaultConfigFile }
if (-not (Test-Path $ConfigFile)) { throw "Arquivo local nao encontrado: $ConfigFile" }
& (Join-Path $PSScriptRoot 'apply_local_config.ps1') -ConfigFile $ConfigFile
exit $LASTEXITCODE

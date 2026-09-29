param([string]$ConfigFile = (Join-Path $PSScriptRoot "mobile_app_config.json"))
$ErrorActionPreference="Stop"
& (Join-Path $PSScriptRoot 'apply_build_config.ps1') -ConfigFile $ConfigFile

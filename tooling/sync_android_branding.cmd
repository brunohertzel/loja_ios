@echo off
setlocal
if "%~1"=="" (
  echo Uso:
  echo   sync_android_branding.cmd URL_DA_API_MOBILE
  echo Exemplo:
  echo   sync_android_branding.cmd https://cliente.exemplo.com/api/mobile/v1
  echo.
  echo Tambem e possivel aplicar um JSON exportado pelo modulo:
  echo   sync_android_branding.cmd .\tooling\mobile_app_config.json
  exit /b 1
)

if exist "%~1" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_android_branding.ps1" -ConfigFile "%~1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_android_branding.ps1" -ApiBaseUrl "%~1"
)
exit /b %ERRORLEVEL%

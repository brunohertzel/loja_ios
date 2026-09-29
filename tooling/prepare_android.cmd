@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tooling\prepare_android.ps1" %*
set ERR=%ERRORLEVEL%
if not "%ERR%"=="0" (
  echo.
  echo Falha ao preparar o projeto. Codigo: %ERR%
  exit /b %ERR%
)
echo.
echo Projeto Android preparado com sucesso.
endlocal

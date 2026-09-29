@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply_local_config.ps1" %*

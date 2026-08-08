@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AlecaFrame-ZH.ps1"
echo.
pause

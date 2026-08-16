@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AlecaFrame-ZH-OcrPrerequisites.ps1"
echo.
pause

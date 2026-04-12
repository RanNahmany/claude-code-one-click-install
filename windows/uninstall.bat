@echo off
:: Claude Code One-Click Uninstaller - Windows
:: Removes everything installed by the installer
::
:: Usage:
::   uninstall.bat
::   uninstall.bat -debug
setlocal enabledelayedexpansion

set "DEBUG_MODE=false"
if /i "%1"=="-debug" set "DEBUG_MODE=true"
if /i "%1"=="--debug" set "DEBUG_MODE=true"

echo ========================================
echo    Claude Code One-Click Uninstaller
echo ========================================
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -NoExit -Command ^
    "& { param([switch]$Debug) . '%~dp0src\uninstaller.ps1' @PSBoundParameters }" %*

pause
exit /b 0

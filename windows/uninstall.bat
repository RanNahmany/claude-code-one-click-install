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

set "REPO_BASE=https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/windows"

echo ========================================
echo    Claude Code One-Click Uninstaller
echo ========================================
echo.

:: Check if local files exist
set "LOCAL_MODE=false"
set "SCRIPT_DIR=%~dp0"

if exist "%SCRIPT_DIR%src\uninstaller.ps1" (
    echo Local uninstaller detected
    set "LOCAL_MODE=true"
    set "UNINSTALL_SCRIPT=%SCRIPT_DIR%src\uninstaller.ps1"
)

if "%LOCAL_MODE%"=="false" (
    echo Downloading uninstaller from GitHub...
    set "TEMP_DIR=%TEMP%\ClaudeCodeUninstaller_%RANDOM%"
    mkdir "!TEMP_DIR!" 2>nul

    :: Try PowerShell download (most reliable in PowerShell environments)
    powershell -Command "try { Invoke-WebRequest -Uri '!REPO_BASE!/src/uninstaller.ps1' -OutFile '!TEMP_DIR!\uninstaller.ps1' -UseBasicParsing } catch { exit 1 }"
    if !errorlevel! neq 0 (
        echo ERROR: Failed to download uninstaller from GitHub
        echo Please check your internet connection and try again.
        goto :cleanup
    )

    echo Downloaded successfully!
    set "UNINSTALL_SCRIPT=!TEMP_DIR!\uninstaller.ps1"
)

echo.
echo Starting uninstall...
echo.

if "%DEBUG_MODE%"=="true" (
    PowerShell -NoProfile -ExecutionPolicy Bypass -NoExit -File "!UNINSTALL_SCRIPT!" -Debug
) else (
    PowerShell -NoProfile -ExecutionPolicy Bypass -NoExit -File "!UNINSTALL_SCRIPT!"
)

:cleanup
if "%LOCAL_MODE%"=="false" (
    if defined TEMP_DIR (
        cd /d "%USERPROFILE%"
        rmdir /s /q "%TEMP_DIR%" 2>nul
    )
)

pause
exit /b 0

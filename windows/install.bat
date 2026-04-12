@echo off
:: Claude Code One-Click Installer - Windows Launcher
:: Automatically detects local vs remote installation mode
::
:: Usage:
::   install.bat                    (from cloned repo or downloaded file)
::   install.bat -debug             (enable debug output)
::   curl -L "...install.bat" -o install.bat && install.bat  (single command)
setlocal enabledelayedexpansion

:: Check for debug argument
set "DEBUG_MODE=false"
if /i "%1"=="-debug" set "DEBUG_MODE=true"
if /i "%1"=="--debug" set "DEBUG_MODE=true"

:: Set GitHub repository base URL
set "REPO_BASE=https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/windows"

echo ========================================
echo    Claude Code One-Click Installer
echo ========================================
echo.

:: Check if we're running from a cloned repository (local files exist)
set "LOCAL_MODE=false"
set "SCRIPT_DIR=%~dp0"

if "%DEBUG_MODE%"=="true" (
    echo [DEBUG] Script directory: %SCRIPT_DIR%
    echo [DEBUG] Checking for local files...
)

if exist "%SCRIPT_DIR%src\installer.ps1" (
    if exist "%SCRIPT_DIR%src\config.json" (
        echo Local installation files detected - using cloned repository
        set "LOCAL_MODE=true"
        set "INSTALL_DIR=%SCRIPT_DIR%"
        if "%DEBUG_MODE%"=="true" echo [DEBUG] Local mode enabled, install dir: %INSTALL_DIR%
    )
)

if "%LOCAL_MODE%"=="false" (
    echo No local files found - downloading from GitHub...
    echo.

    :: Check if curl is available
    if "%DEBUG_MODE%"=="true" echo [DEBUG] Checking curl availability...
    curl --version >nul 2>&1
    if !errorlevel! neq 0 (
        echo curl not found, trying PowerShell alternative...
        set "USE_POWERSHELL=true"
    ) else (
        set "USE_POWERSHELL=false"
    )

    :: Create temporary directory
    set "TEMP_DIR=%TEMP%\ClaudeCodeInstaller_%RANDOM%"
    if "%DEBUG_MODE%"=="true" echo [DEBUG] Creating temp directory: !TEMP_DIR!

    mkdir "!TEMP_DIR!" 2>nul
    mkdir "!TEMP_DIR!\src" 2>nul

    echo Downloading configuration files...
    call :DownloadFile "!REPO_BASE!/src/config.json" "!TEMP_DIR!\src\config.json"
    if !errorlevel! neq 0 (
        echo ERROR: Failed to download config.json from GitHub
        echo.
        echo Possible causes:
        echo - Network connectivity issues
        echo - Corporate firewall blocking GitHub
        echo.
        echo Please try:
        echo 1. Check internet connection
        echo 2. Download repository manually from GitHub
        echo 3. Run from administrator command prompt
        goto :cleanup
    )

    echo Downloading installer script...
    call :DownloadFile "!REPO_BASE!/src/installer.ps1" "!TEMP_DIR!\src\installer.ps1"
    if !errorlevel! neq 0 (
        echo ERROR: Failed to download installer.ps1
        goto :cleanup
    )

    echo.
    echo Files downloaded successfully!
    set "INSTALL_DIR=!TEMP_DIR!"
) else (
    echo Using local repository files
)

echo.
echo Starting installation...
echo.

:: Change to installation directory and run installer
if "%DEBUG_MODE%"=="true" (
    echo [DEBUG] INSTALL_DIR is: !INSTALL_DIR!
    echo [DEBUG] PowerShell script path: !INSTALL_DIR!\src\installer.ps1
    echo [DEBUG] Press any key to continue...
    pause > nul
    PowerShell -NoProfile -ExecutionPolicy Bypass -NoExit -File "!INSTALL_DIR!\src\installer.ps1" -Debug
) else (
    PowerShell -NoProfile -ExecutionPolicy Bypass -NoExit -File "!INSTALL_DIR!\src\installer.ps1"
)

:cleanup
if "%LOCAL_MODE%"=="false" (
    echo.
    echo Cleaning up temporary files...
    cd /d "%USERPROFILE%"
    rmdir /s /q "%TEMP_DIR%" 2>nul
)

echo.
echo Installation complete!
pause
exit /b 0

:DownloadFile
:: Download file using curl or PowerShell fallback
:: Usage: call :DownloadFile "url" "destination"
set "url=%~1"
set "dest=%~2"

if "%DEBUG_MODE%"=="true" (
    echo [DEBUG] Downloading: !url!
    echo [DEBUG] Destination: !dest!
)

if "%USE_POWERSHELL%"=="true" (
    if "%DEBUG_MODE%"=="true" echo [DEBUG] Using PowerShell Invoke-WebRequest...
    powershell -Command "try { Invoke-WebRequest -Uri '%url%' -OutFile '%dest%' -UseBasicParsing } catch { exit 1 }"
    set "download_result=!errorlevel!"
    exit /b !download_result!
) else (
    if "%DEBUG_MODE%"=="true" (
        curl -L -v -o "!dest!" "!url!" 2>&1
    ) else (
        curl -L -s -o "!dest!" "!url!"
    )
    set "download_result=!errorlevel!"
    exit /b !download_result!
)

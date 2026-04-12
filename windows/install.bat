@echo off
:: Claude Code Windows Installer - Smart Batch Launcher
:: Automatically detects local vs remote installation mode
:: - Local mode: Uses files from cloned repository
:: - Remote mode: Downloads latest files from GitHub
:: 
:: Usage: 
::   install.bat (from cloned repo or downloaded file)
::   curl -L "...install.bat" -o install.bat && install.bat (single command)
::   install.bat -debug (enable debug output)
setlocal enabledelayedexpansion

:: Check for debug argument
set "DEBUG_MODE=false"
if /i "%1"=="-debug" set "DEBUG_MODE=true"
if /i "%1"=="--debug" set "DEBUG_MODE=true"

:: Set GitHub repository base URL globally
set "REPO_BASE=https://raw.githubusercontent.com/nitromike502/claude-code-windows-installer/main"

echo ========================================
echo      Claude Code Installer            
echo ========================================
echo.

:: Check if we're running from a cloned repository (local files exist)
set "LOCAL_MODE=false"
set "SCRIPT_DIR=%~dp0"

if "%DEBUG_MODE%"=="true" (
    echo [DEBUG] Script directory: %SCRIPT_DIR%
    echo [DEBUG] Checking for local files...
    echo [DEBUG] Looking for: %SCRIPT_DIR%src\installer.ps1
    echo [DEBUG] Looking for: %SCRIPT_DIR%src\config.json
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
        if "%DEBUG_MODE%"=="true" echo [DEBUG] curl not available, will use PowerShell Invoke-WebRequest
    ) else (
        set "USE_POWERSHELL=false"
        if "%DEBUG_MODE%"=="true" (
            echo [DEBUG] curl is available
            curl --version 2>&1 | findstr /C:"curl"
        )
    )
    
    :: Create temporary directory with subdirectories
    set "TEMP_DIR=%TEMP%\ClaudeCodeInstaller_%RANDOM%"
    if "%DEBUG_MODE%"=="true" echo [DEBUG] Creating temp directory: !TEMP_DIR!
    
    mkdir "!TEMP_DIR!" 2>nul
    mkdir "!TEMP_DIR!\src" 2>nul
    mkdir "!TEMP_DIR!\assets" 2>nul
    
    if "%DEBUG_MODE%"=="true" (
        echo [DEBUG] Directory creation results:
        if exist "!TEMP_DIR!" (echo [DEBUG] - !TEMP_DIR! [OK]) else (echo [DEBUG] - !TEMP_DIR! [FAILED])
        if exist "!TEMP_DIR!\src" (echo [DEBUG] - !TEMP_DIR!\src [OK]) else (echo [DEBUG] - !TEMP_DIR!\src [FAILED])
        if exist "!TEMP_DIR!\assets" (echo [DEBUG] - !TEMP_DIR!\assets [OK]) else (echo [DEBUG] - !TEMP_DIR!\assets [FAILED])
    )
    
    if "%DEBUG_MODE%"=="true" (
        echo [DEBUG] REPO_BASE set to: !REPO_BASE!
        echo [DEBUG] Full URL will be: !REPO_BASE!/src/config.json
        echo [DEBUG] TEMP_DIR set to: !TEMP_DIR!
    )
    
    echo Downloading configuration files...
    call :DownloadFile "!REPO_BASE!/src/config.json" "!TEMP_DIR!\src\config.json"
    if !errorlevel! neq 0 (
        echo ERROR: Failed to download config.json from GitHub
        echo.
        echo Possible causes:
        echo - Network connectivity issues
        echo - Corporate firewall blocking GitHub
        echo - SSL/TLS certificate issues
        echo.
        echo Please try:
        echo 1. Check internet connection
        echo 2. Download repository manually from GitHub
        echo 3. Run from administrator command prompt
        echo 4. Configure proxy settings if behind corporate firewall
        goto :cleanup
    )
    
    echo Downloading installer script...
    call :DownloadFile "!REPO_BASE!/src/installer.ps1" "!TEMP_DIR!\src\installer.ps1"
    if !errorlevel! neq 0 (
        echo ERROR: Failed to download installer.ps1
        goto :cleanup
    )
    
    echo Downloading icon file...
    call :DownloadFile "!REPO_BASE!/assets/claude-color.ico" "!TEMP_DIR!\assets\claude-color.ico"
    if !errorlevel! neq 0 (
        echo WARNING: Failed to download icon file, installer will use default icon
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
    if exist "!INSTALL_DIR!\src\installer.ps1" (
        echo [DEBUG] PowerShell script file exists
    ) else (
        echo [DEBUG] PowerShell script file NOT FOUND
    )
)

cd /d "!INSTALL_DIR!"
if "%DEBUG_MODE%"=="true" (
    echo [DEBUG] Changed to directory: !CD!
    echo [DEBUG] About to run PowerShell installer with debug mode...
    echo [DEBUG] Full command: PowerShell -NoProfile -ExecutionPolicy Bypass -NoExit -File "!INSTALL_DIR!\src\installer.ps1" -Debug
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
:: Download file using curl or PowerShell fallback with comprehensive error handling
:: Automatically detects available download method and provides debug output
:: Usage: call :DownloadFile "url" "destination"
:: Returns: Exit code 0 on success, non-zero on failure
set "url=%~1"
set "dest=%~2"

if "%DEBUG_MODE%"=="true" (
    echo [DEBUG] Downloading: !url!
    echo [DEBUG] Destination: !dest!
    echo [DEBUG] Method: !USE_POWERSHELL!
)

if "%USE_POWERSHELL%"=="true" (
    :: Use PowerShell Invoke-WebRequest
    if "%DEBUG_MODE%"=="true" echo [DEBUG] Using PowerShell Invoke-WebRequest...
    powershell -Command "try { Write-Host '[DEBUG] Starting PowerShell download...' -ForegroundColor Gray; Invoke-WebRequest -Uri '%url%' -OutFile '%dest%' -UseBasicParsing -Verbose; Write-Host '[DEBUG] PowerShell download completed' -ForegroundColor Gray } catch { Write-Host '[DEBUG] PowerShell download failed:' $_.Exception.Message -ForegroundColor Red; exit 1 }"
    set "download_result=!errorlevel!"
    if "%DEBUG_MODE%"=="true" echo [DEBUG] PowerShell download exit code: !download_result!
    exit /b !download_result!
) else (
    :: Use curl
    if "%DEBUG_MODE%"=="true" echo [DEBUG] Using curl...
    if "%DEBUG_MODE%"=="true" (
        curl -L -v -o "!dest!" "!url!" 2>&1
        set "download_result=!errorlevel!"
        echo [DEBUG] curl exit code: !download_result!
        if exist "!dest!" (
            echo [DEBUG] File created successfully, size:
            for %%F in ("!dest!") do echo [DEBUG] %%~zF bytes
        ) else (
            echo [DEBUG] File was not created
        )
    ) else (
        curl -L -s -o "!dest!" "!url!"
        set "download_result=!errorlevel!"
    )
    exit /b !download_result!
)
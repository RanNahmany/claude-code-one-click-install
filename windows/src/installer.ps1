# Claude Code Windows Installer
# Installs VS Code, Git, Node.js, and Claude Code with zero manual steps
#
# Usage:
#   installer.ps1                    # Standard installation
#   installer.ps1 -Debug             # Enable debug output for troubleshooting

param(
    [switch]$Debug
)

# ============================================================
# Utility Functions
# ============================================================

function Get-InstallerConfig {
    $configPath = Join-Path $PSScriptRoot "config.json"
    Write-DebugOutput "Looking for config file at: $configPath"

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    try {
        $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-DebugOutput "Config loaded successfully"
        return $configContent
    }
    catch {
        throw "Failed to parse configuration file: $($_.Exception.Message)"
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminPrivileges {
    param([string]$ScriptPath)

    Write-Host "Admin permissions are needed to install system tools. Please click 'Yes' on the prompt." -ForegroundColor Yellow
    Write-DebugOutput "Current script path: $ScriptPath"
    Start-Sleep -Seconds 2

    try {
        $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
        if ($Debug) {
            $arguments += "-Debug"
            Write-DebugOutput "Adding -Debug parameter to elevated process"
        }

        Start-Process powershell -Verb RunAs -ArgumentList $arguments -WorkingDirectory (Get-Location)
    }
    catch {
        Write-Host "Failed to elevate privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator manually and execute the script." -ForegroundColor Yellow
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit
}

function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-DebugOutput {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )
    if ($Debug) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

function Write-StepHeader {
    param(
        [int]$StepNumber,
        [string]$Description
    )
    Write-Host ""
    Write-Host "[$StepNumber/11] $Description" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  [SKIP] $Message" -ForegroundColor Yellow
}

function Write-StepError {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Test-NodeVersion {
    param([string]$Version)

    try {
        $versionNumber = $Version -replace 'v', ''
        $versionParts = $versionNumber.Split('.')
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        $patch = [int]$versionParts[2]

        $minVersion = $script:Config.dependencies.nodejs.minimumVersion
        $minParts = $minVersion.Split('.')
        $minMajor = [int]$minParts[0]
        $minMinor = [int]$minParts[1]
        $minPatch = [int]$minParts[2]

        if ($major -gt $minMajor) { return $true }
        if ($major -eq $minMajor -and $minor -gt $minMinor) { return $true }
        if ($major -eq $minMajor -and $minor -eq $minMinor -and $patch -ge $minPatch) { return $true }

        return $false
    }
    catch {
        return $false
    }
}

function Find-VSCodeCmd {
    # Find the 'code' CLI command (.cmd wrapper, not .exe)
    # Must check multiple locations because admin elevation may change LOCALAPPDATA
    $paths = @(
        # Current user (works when not elevated or same-user elevation)
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        # System-wide install
        "C:\Program Files\Microsoft VS Code\bin\code.cmd",
        "C:\Program Files (x86)\Microsoft VS Code\bin\code.cmd"
    )

    # Also check the original user's profile (in case running elevated as different user)
    $userProfile = $env:USERPROFILE
    if ($userProfile) {
        $paths += "$userProfile\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd"
    }

    # Check all user profiles as last resort
    $usersDir = "C:\Users"
    if (Test-Path $usersDir) {
        Get-ChildItem $usersDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $paths += "$($_.FullName)\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd"
        }
    }

    foreach ($p in ($paths | Select-Object -Unique)) {
        if (Test-Path $p) {
            Write-DebugOutput "Found VS Code CLI at: $p"
            return $p
        }
    }
    return $null
}

# ============================================================
# Installation Functions
# ============================================================

function Install-VSCode {
    Write-StepHeader 1 "Installing VS Code..."

    # Check if already installed
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd -or (Find-VSCodeCmd)) {
        Write-Skip "VS Code is already installed"
        return
    }

    # Try winget first
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    $installed = $false

    if ($wingetAvailable) {
        Write-DebugOutput "Attempting VS Code installation via winget..."
        try {
            $result = winget install --id Microsoft.VisualStudioCode -e --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
            }
            Write-DebugOutput "winget exit code: $LASTEXITCODE"
        }
        catch {
            Write-DebugOutput "winget failed: $($_.Exception.Message)"
        }
    }

    # Fallback to direct download
    if (-not $installed) {
        Write-DebugOutput "Downloading VS Code installer..."
        $vscodeUrl = $script:Config.urls.vscodeWindows
        $vscodeInstaller = "$env:TEMP\vscode-installer.exe"

        Invoke-WebRequest -Uri $vscodeUrl -OutFile $vscodeInstaller -UseBasicParsing

        $installProcess = Start-Process -FilePath $vscodeInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/MERGETASKS=!runcode,addtopath" -Wait -PassThru
        if ($installProcess.ExitCode -ne 0) {
            throw "VS Code installer failed with exit code $($installProcess.ExitCode)"
        }

        Remove-Item $vscodeInstaller -Force -ErrorAction SilentlyContinue
    }

    # Add to PATH for current session
    $vscodeBinPath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
    if (Test-Path $vscodeBinPath) {
        $env:Path += ";$vscodeBinPath"
    }

    # Verify
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd) {
        $version = (code --version 2>$null | Select-Object -First 1)
        Write-Success "VS Code $version installed"
    }
    else {
        Write-Success "VS Code installed (restart terminal to use 'code' command)"
    }
}

function Install-Git {
    Write-StepHeader 2 "Installing Git..."

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVersion = git --version 2>$null
        Write-Skip "Git is already installed ($gitVersion)"
        return
    }

    # Try winget first
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    $installed = $false

    if ($wingetAvailable) {
        Write-DebugOutput "Attempting Git installation via winget..."
        try {
            $result = winget install --id Git.Git -e --source winget --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
            }
            Write-DebugOutput "winget exit code: $LASTEXITCODE"
        }
        catch {
            Write-DebugOutput "winget failed: $($_.Exception.Message)"
        }
    }

    # Fallback to direct download
    if (-not $installed) {
        Write-DebugOutput "Downloading Git installer..."
        $gitInstaller = "$env:TEMP\git-installer.exe"

        # Use the GitHub releases latest redirect
        $gitUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-64-bit.exe"
        Write-DebugOutput "Download URL: $gitUrl"

        # Try to get the actual latest release URL via GitHub API
        try {
            $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" -UseBasicParsing
            $asset = $releaseInfo.assets | Where-Object { $_.name -match "Git-.*-64-bit\.exe$" } | Select-Object -First 1
            if ($asset) {
                $gitUrl = $asset.browser_download_url
                Write-DebugOutput "Resolved latest Git URL: $gitUrl"
            }
        }
        catch {
            Write-DebugOutput "Could not resolve latest Git release, using fallback URL"
        }

        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing

        $installProcess = Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait -PassThru
        if ($installProcess.ExitCode -ne 0) {
            throw "Git installer failed with exit code $($installProcess.ExitCode)"
        }

        Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
    }

    # Add Git to PATH for current session
    $gitPaths = @("C:\Program Files\Git\bin", "C:\Program Files (x86)\Git\bin")
    foreach ($gp in $gitPaths) {
        if (Test-Path $gp) {
            $env:Path += ";$gp"
            break
        }
    }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVersion = git --version 2>$null
        Write-Success "Git installed ($gitVersion)"
    }
    else {
        Write-Success "Git installed (restart terminal to use 'git' command)"
    }
}

function Set-GitConfig {
    Write-StepHeader 3 "Configuring Git..."

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-StepError "Git not found in PATH, skipping configuration"
        return
    }

    $gitConfig = $script:Config.git.config
    $gitConfig.PSObject.Properties | ForEach-Object {
        $key = $_.Name
        $value = $_.Value
        Write-DebugOutput "Setting git config: $key = $value"
        git config --global $key "$value" 2>$null
    }

    Write-Success "Git configured (default branch: main, editor: VS Code)"
}

function Install-NodeJS {
    Write-StepHeader 4 "Installing Node.js..."

    # Check if Node.js is already installed and meets minimum version
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVersion = node -v 2>$null
        if (Test-NodeVersion $nodeVersion) {
            $npmVersion = npm -v 2>$null
            Write-Skip "Node.js $nodeVersion is already installed (npm v$npmVersion)"
            return
        }
        else {
            $minVersion = $script:Config.dependencies.nodejs.minimumVersion
            Write-ColoredOutput "  Node.js $nodeVersion found but v$minVersion+ required. Upgrading..." "Yellow"
        }
    }

    # Install nvm-windows
    $nvmCmd = Get-Command nvm -ErrorAction SilentlyContinue
    $nvmExe = $null

    if (-not $nvmCmd) {
        Write-DebugOutput "Installing nvm-windows..."
        $nvmUrl = $script:Config.urls.nvmWindows
        $nvmInstaller = "$env:TEMP\nvm-setup.exe"

        Invoke-WebRequest -Uri $nvmUrl -OutFile $nvmInstaller -UseBasicParsing

        # nvm-windows uses InnoSetup — /VERYSILENT is the correct silent flag
        $installProcess = Start-Process -FilePath $nvmInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait -PassThru
        Write-DebugOutput "nvm-windows installer exit code: $($installProcess.ExitCode)"

        Remove-Item $nvmInstaller -Force -ErrorAction SilentlyContinue

        # Refresh PATH from registry so we pick up what the installer set
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"

        # Also set NVM environment variables from registry
        $nvmHome = [System.Environment]::GetEnvironmentVariable("NVM_HOME", "Machine")
        if (-not $nvmHome) { $nvmHome = [System.Environment]::GetEnvironmentVariable("NVM_HOME", "User") }
        if ($nvmHome) {
            $env:NVM_HOME = $nvmHome
            Write-DebugOutput "NVM_HOME set to: $nvmHome"
        }
        else {
            # Fallback to default location
            $env:NVM_HOME = "$env:APPDATA\nvm"
            $env:Path += ";$env:APPDATA\nvm"
        }

        $nvmSymlink = [System.Environment]::GetEnvironmentVariable("NVM_SYMLINK", "Machine")
        if (-not $nvmSymlink) { $nvmSymlink = [System.Environment]::GetEnvironmentVariable("NVM_SYMLINK", "User") }
        if ($nvmSymlink) {
            $env:NVM_SYMLINK = $nvmSymlink
        }
        else {
            $env:NVM_SYMLINK = "$env:ProgramFiles\nodejs"
        }

        Start-Sleep -Seconds 2
        Write-Success "nvm-windows installed"
    }

    # Find nvm executable
    $nvmExe = "$env:NVM_HOME\nvm.exe"
    if (-not (Test-Path $nvmExe)) {
        $nvmExe = "$env:APPDATA\nvm\nvm.exe"
    }
    if (-not (Test-Path $nvmExe)) {
        $nvmExe = "C:\ProgramData\nvm\nvm.exe"
    }

    if (-not (Test-Path $nvmExe)) {
        throw "nvm installation failed - executable not found at any known location"
    }

    Write-DebugOutput "Using nvm at: $nvmExe"

    # Install Node.js LTS via nvm
    Write-DebugOutput "Installing Node.js LTS via nvm..."
    & $nvmExe install lts 2>&1 | ForEach-Object { Write-DebugOutput "nvm: $_" }
    Start-Sleep -Seconds 3

    & $nvmExe use lts 2>&1 | ForEach-Object { Write-DebugOutput "nvm: $_" }
    Start-Sleep -Seconds 2

    # Refresh PATH again after nvm install (nvm creates the nodejs symlink)
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    # Also ensure the nodejs symlink is in PATH
    $nodeSymlink = $env:NVM_SYMLINK
    if (-not $nodeSymlink) { $nodeSymlink = "$env:ProgramFiles\nodejs" }
    if ((Test-Path $nodeSymlink) -and ($env:Path -notlike "*$nodeSymlink*")) {
        $env:Path += ";$nodeSymlink"
    }

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVersion = node -v 2>$null
        Write-Success "Node.js $nodeVersion installed via nvm"
    }
    else {
        Write-Success "Node.js LTS installed via nvm (restart terminal to use)"
    }
}

function Update-Npm {
    Write-StepHeader 5 "Updating npm..."

    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        Write-Skip "npm not found, skipping update"
        return
    }

    try {
        npm install -g npm@latest 2>&1 | Out-Null
        $npmVersion = npm -v 2>$null
        Write-Success "npm updated to v$npmVersion"
    }
    catch {
        Write-DebugOutput "npm update failed: $($_.Exception.Message)"
        Write-Skip "npm update skipped (current version will work fine)"
    }
}

function Install-ClaudeCode {
    Write-StepHeader 6 "Installing Claude Code..."

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $claudeVersion = claude --version 2>$null
        Write-Skip "Claude Code is already installed ($claudeVersion)"
        return
    }

    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        throw "npm is required to install Claude Code but was not found"
    }

    try {
        npm install -g @anthropic-ai/claude-code 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed with exit code $LASTEXITCODE"
        }

        # Verify
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
        if ($claudeCmd) {
            $claudeVersion = claude --version 2>$null
            Write-Success "Claude Code installed ($claudeVersion)"
        }
        else {
            Write-Success "Claude Code installed"
        }
    }
    catch {
        throw "Failed to install Claude Code: $($_.Exception.Message)"
    }
}

function Install-VSCodeExtensions {
    Write-StepHeader 7 "Installing VS Code extensions..."

    # Find the code CLI command
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    $codePath = if ($codeCmd) {
        $codeCmd.Source
    }
    else {
        Find-VSCodeCmd
    }

    if (-not $codePath) {
        Write-StepError "VS Code 'code' command not found — cannot install extensions"
        Write-ColoredOutput "  Extensions can be installed manually in VS Code: Ctrl+Shift+X" "Yellow"
        return
    }

    Write-DebugOutput "Using VS Code CLI at: $codePath"

    $extensions = $script:Config.vscode.extensions
    foreach ($ext in $extensions) {
        Write-DebugOutput "Installing extension: $ext"
        try {
            $output = & $codePath --install-extension $ext --force 2>&1
            $exitCode = $LASTEXITCODE
            Write-DebugOutput "Extension install output: $output"
            Write-DebugOutput "Extension install exit code: $exitCode"

            if ($exitCode -eq 0) {
                Write-Success "Extension '$ext' installed"
            }
            else {
                Write-StepError "Extension '$ext' install returned exit code $exitCode"
                Write-ColoredOutput "  Install manually in VS Code: Extensions sidebar, search '$ext'" "Yellow"
            }
        }
        catch {
            Write-StepError "Failed to install extension '$ext': $($_.Exception.Message)"
            Write-ColoredOutput "  Install manually in VS Code: Extensions sidebar, search '$ext'" "Yellow"
        }
    }
}

function Set-VSCodeSettings {
    Write-StepHeader 8 "Configuring VS Code settings..."

    # Find the correct user's AppData (may differ when running elevated)
    $settingsDir = "$env:APPDATA\Code\User"

    # If the Code\User dir doesn't exist under current APPDATA, check the USERPROFILE path
    if (-not (Test-Path "$env:APPDATA\Code") -and $env:USERPROFILE) {
        $altSettingsDir = "$env:USERPROFILE\AppData\Roaming\Code\User"
        if (Test-Path "$env:USERPROFILE\AppData\Roaming\Code") {
            $settingsDir = $altSettingsDir
            Write-DebugOutput "Using alternate settings path: $settingsDir"
        }
    }

    $settingsFile = "$settingsDir\settings.json"

    # Ensure directory exists
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }

    # Get desired settings from config
    $desiredSettings = @{}
    $script:Config.vscode.settings.PSObject.Properties | ForEach-Object {
        $desiredSettings[$_.Name] = $_.Value
    }

    # Load existing settings if they exist
    $existingSettings = @{}
    if (Test-Path $settingsFile) {
        try {
            $content = Get-Content $settingsFile -Raw
            if ($content.Trim()) {
                $parsed = $content | ConvertFrom-Json
                $parsed.PSObject.Properties | ForEach-Object {
                    $existingSettings[$_.Name] = $_.Value
                }
            }
        }
        catch {
            Write-DebugOutput "Could not parse existing settings, will create new: $($_.Exception.Message)"
        }
    }

    # Merge: desired settings override, but keep user's other settings
    foreach ($key in $desiredSettings.Keys) {
        $existingSettings[$key] = $desiredSettings[$key]
    }

    # Write as JSON
    $jsonOutput = $existingSettings | ConvertTo-Json -Depth 10
    Set-Content -Path $settingsFile -Value $jsonOutput -Encoding UTF8

    Write-Success "VS Code settings configured ($settingsFile)"
}

# ============================================================
# Main Installation Flow
# ============================================================

try {
    Write-DebugOutput "=== Claude Code Installer Started ==="
    Write-DebugOutput "Script path: $($MyInvocation.MyCommand.Path)"
    Write-DebugOutput "Running as admin: $(Test-Administrator)"

    # Check admin privileges
    if (-not (Test-Administrator)) {
        Request-AdminPrivileges -ScriptPath $MyInvocation.MyCommand.Path
        return
    }

    # Load configuration
    try {
        $script:Config = Get-InstallerConfig
    }
    catch {
        Write-Host "Configuration Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    # Setup
    $Host.UI.RawUI.WindowTitle = "Claude Code Installer"
    Clear-Host

    Write-ColoredOutput "========================================" "Magenta"
    Write-ColoredOutput "   Claude Code One-Click Installer      " "Magenta"
    Write-ColoredOutput "========================================" "Magenta"
    Write-ColoredOutput ""
    Write-ColoredOutput "This will install: VS Code, Git, Node.js, and Claude Code" "White"
    Write-ColoredOutput "Existing installations will be detected and skipped." "Gray"

    # Run installation steps
    Install-VSCode           # Step 1
    Install-Git              # Step 2
    Set-GitConfig            # Step 3
    Install-NodeJS           # Step 4
    Update-Npm               # Step 5
    Install-ClaudeCode       # Step 6
    Install-VSCodeExtensions # Step 7
    Set-VSCodeSettings       # Step 8

    # ============================================================
    # Verification Summary
    # ============================================================

    Write-Host ""
    Write-ColoredOutput "========================================" "Green"
    Write-ColoredOutput "       Installation Complete!           " "Green"
    Write-ColoredOutput "========================================" "Green"
    Write-Host ""
    Write-ColoredOutput "Verification:" "Cyan"

    # Check each tool
    $toolChecks = @(
        @{ Name = "VS Code"; Cmd = "code"; Args = @("--version") },
        @{ Name = "Git"; Cmd = "git"; Args = @("--version") },
        @{ Name = "Node.js"; Cmd = "node"; Args = @("-v") },
        @{ Name = "npm"; Cmd = "npm"; Args = @("-v") },
        @{ Name = "Claude Code"; Cmd = "claude"; Args = @("--version") }
    )

    foreach ($tool in $toolChecks) {
        $padding = ' ' * (16 - $tool.Name.Length)
        try {
            $cmd = Get-Command $tool.Cmd -ErrorAction SilentlyContinue
            if ($cmd) {
                $version = (& $tool.Cmd $tool.Args 2>$null | Select-Object -First 1)
                if ($version) {
                    Write-Host "  [OK] $($tool.Name)$padding$version" -ForegroundColor Green
                }
                else {
                    Write-Host "  [OK] $($tool.Name)${padding}installed" -ForegroundColor Green
                }
            }
            else {
                Write-Host "  [--] $($tool.Name)${padding}not in PATH" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  [--] $($tool.Name)${padding}not in PATH" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-ColoredOutput "Next steps:" "White"
    Write-Host "  1. Open VS Code (type 'code' in terminal or find it in Start menu)" -ForegroundColor White
    Write-Host "  2. Open a terminal in VS Code (Ctrl + backtick)" -ForegroundColor White
    Write-Host "  3. Type 'claude' to start Claude Code" -ForegroundColor White
    Write-Host "  4. You will be prompted to authenticate on first run" -ForegroundColor White
    Write-Host ""
    Write-ColoredOutput "Note: You may need to restart your terminal for all PATH changes to take effect." "Yellow"
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-DebugOutput "Installation failed with error: $($_.Exception.Message)"
    Write-DebugOutput "Stack trace: $($_.ScriptStackTrace)"

    Write-Host ""
    Write-ColoredOutput "========================================" "Red"
    Write-ColoredOutput "       Installation Failed              " "Red"
    Write-ColoredOutput "========================================" "Red"
    Write-Host ""
    Write-ColoredOutput "Error: $($_.Exception.Message)" "Red"

    if ($Debug) {
        Write-Host ""
        Write-ColoredOutput "Debug Information:" "Yellow"
        Write-ColoredOutput "Stack trace: $($_.ScriptStackTrace)" "Gray"
    }

    Write-Host ""
    Write-ColoredOutput "Please check your internet connection and try again." "Yellow"
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

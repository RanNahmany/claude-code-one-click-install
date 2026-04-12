# Claude Code Windows Uninstaller
# Removes VS Code, Git, Node.js (nvm-windows), and Claude Code
#
# Usage:
#   uninstaller.ps1                  # Standard uninstall
#   uninstaller.ps1 -Debug           # Enable debug output

param(
    [switch]$Debug
)

# ============================================================
# Utility Functions
# ============================================================

function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-DebugOutput {
    param([string]$Message)
    if ($Debug) {
        Write-Host "[DEBUG] $Message" -ForegroundColor Gray
    }
}

function Write-StepHeader {
    param(
        [int]$StepNumber,
        [int]$TotalSteps,
        [string]$Description
    )
    Write-Host ""
    Write-Host "[$StepNumber/$TotalSteps] $Description" -ForegroundColor Cyan
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

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminPrivileges {
    param([string]$ScriptPath)

    Write-Host "Admin permissions are needed to uninstall system tools. Please click 'Yes' on the prompt." -ForegroundColor Yellow
    Start-Sleep -Seconds 2

    try {
        $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
        if ($Debug) { $arguments += "-Debug" }
        Start-Process powershell -Verb RunAs -ArgumentList $arguments -WorkingDirectory (Get-Location)
    }
    catch {
        Write-Host "Failed to elevate privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator manually." -ForegroundColor Yellow
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit
}

# ============================================================
# Uninstall Functions
# ============================================================

function Uninstall-ClaudeCode {
    Write-StepHeader 1 6 "Uninstalling Claude Code..."

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Skip "Claude Code is not installed"
        return
    }

    try {
        npm uninstall -g @anthropic-ai/claude-code 2>&1 | Out-Null
        Write-Success "Claude Code uninstalled"
    }
    catch {
        Write-StepError "Failed to uninstall Claude Code: $($_.Exception.Message)"
    }

    # Clean up Claude Code config directory
    $claudeConfigDir = "$env:USERPROFILE\.claude"
    if (Test-Path $claudeConfigDir) {
        Write-DebugOutput "Removing Claude Code config: $claudeConfigDir"
        Remove-Item -Path $claudeConfigDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Claude Code configuration removed"
    }
}

function Uninstall-VSCodeExtensions {
    Write-StepHeader 2 6 "Removing VS Code extensions..."

    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCmd) {
        # Try common path
        $codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
        if (-not (Test-Path $codePath)) {
            Write-Skip "VS Code not found, skipping extension removal"
            return
        }
        $codeExe = $codePath
    }
    else {
        $codeExe = "code"
    }

    try {
        & $codeExe --uninstall-extension anthropics.claude-code --force 2>&1 | Out-Null
        Write-Success "Claude Code extension removed"
    }
    catch {
        Write-DebugOutput "Extension removal failed: $($_.Exception.Message)"
    }
}

function Uninstall-VSCode {
    Write-StepHeader 3 6 "Uninstalling VS Code..."

    # Check if installed
    $vscodeInstalled = (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or
                       (Test-Path "C:\Program Files\Microsoft VS Code\Code.exe")

    if (-not $vscodeInstalled) {
        Write-Skip "VS Code is not installed"
        return
    }

    # Try winget first
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    $uninstalled = $false

    if ($wingetAvailable) {
        try {
            winget uninstall --id Microsoft.VisualStudioCode -e --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $uninstalled = $true }
        }
        catch {
            Write-DebugOutput "winget uninstall failed: $($_.Exception.Message)"
        }
    }

    # Fallback: find and run uninstaller
    if (-not $uninstalled) {
        $uninstallers = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\unins000.exe",
            "C:\Program Files\Microsoft VS Code\unins000.exe"
        )
        foreach ($uninstaller in $uninstallers) {
            if (Test-Path $uninstaller) {
                Write-DebugOutput "Running uninstaller: $uninstaller"
                $proc = Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait -PassThru
                if ($proc.ExitCode -eq 0) { $uninstalled = $true }
                break
            }
        }
    }

    if ($uninstalled) {
        Write-Success "VS Code uninstalled"
    }
    else {
        Write-StepError "Could not uninstall VS Code automatically. Please uninstall manually from Settings > Apps."
    }

    # Clean up VS Code settings
    $vscodeDirs = @(
        "$env:APPDATA\Code",
        "$env:USERPROFILE\.vscode"
    )
    foreach ($dir in $vscodeDirs) {
        if (Test-Path $dir) {
            Write-DebugOutput "Removing VS Code data: $dir"
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Success "VS Code settings and data cleaned up"
}

function Uninstall-NodeJS {
    Write-StepHeader 4 6 "Uninstalling Node.js and nvm-windows..."

    # Check for nvm-windows
    $nvmDir = "$env:APPDATA\nvm"
    $nvmInstalled = Test-Path $nvmDir

    if (-not $nvmInstalled) {
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if (-not $nodeCmd) {
            Write-Skip "Node.js and nvm-windows are not installed"
            return
        }
    }

    # Uninstall nvm-windows via its uninstaller if available
    $nvmUninstaller = "$nvmDir\unins000.exe"
    if (Test-Path $nvmUninstaller) {
        Write-DebugOutput "Running nvm-windows uninstaller"
        $proc = Start-Process -FilePath $nvmUninstaller -ArgumentList "/VERYSILENT" -Wait -PassThru
        Write-DebugOutput "nvm uninstaller exit code: $($proc.ExitCode)"
    }

    # Clean up nvm directories
    $nvmDirs = @(
        "$env:APPDATA\nvm",
        "$env:ProgramFiles\nodejs"
    )
    foreach ($dir in $nvmDirs) {
        if (Test-Path $dir) {
            Write-DebugOutput "Removing: $dir"
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Clean up environment variables
    [System.Environment]::SetEnvironmentVariable("NVM_HOME", $null, "User")
    [System.Environment]::SetEnvironmentVariable("NVM_SYMLINK", $null, "User")

    # Clean nvm/node from user PATH
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath) {
        $cleanPath = ($userPath -split ';' | Where-Object {
            $_ -notmatch 'nvm' -and $_ -notmatch 'nodejs'
        }) -join ';'
        [System.Environment]::SetEnvironmentVariable("Path", $cleanPath, "User")
    }

    Write-Success "Node.js and nvm-windows uninstalled"
}

function Uninstall-Git {
    Write-StepHeader 5 6 "Uninstalling Git..."

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        $gitInstalled = (Test-Path "C:\Program Files\Git") -or (Test-Path "C:\Program Files (x86)\Git")
        if (-not $gitInstalled) {
            Write-Skip "Git is not installed"
            return
        }
    }

    # Try winget first
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    $uninstalled = $false

    if ($wingetAvailable) {
        try {
            winget uninstall --id Git.Git -e --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $uninstalled = $true }
        }
        catch {
            Write-DebugOutput "winget uninstall failed: $($_.Exception.Message)"
        }
    }

    # Fallback: find Git uninstaller
    if (-not $uninstalled) {
        $gitUninstallers = @(
            "C:\Program Files\Git\unins000.exe",
            "C:\Program Files (x86)\Git\unins000.exe"
        )
        foreach ($uninstaller in $gitUninstallers) {
            if (Test-Path $uninstaller) {
                Write-DebugOutput "Running Git uninstaller: $uninstaller"
                $proc = Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait -PassThru
                if ($proc.ExitCode -eq 0) { $uninstalled = $true }
                break
            }
        }
    }

    if ($uninstalled) {
        Write-Success "Git uninstalled"
    }
    else {
        Write-StepError "Could not uninstall Git automatically. Please uninstall manually from Settings > Apps."
    }

    # Clean up Git global config
    $gitconfigPath = "$env:USERPROFILE\.gitconfig"
    if (Test-Path $gitconfigPath) {
        Write-DebugOutput "Removing .gitconfig"
        Remove-Item -Path $gitconfigPath -Force -ErrorAction SilentlyContinue
        Write-Success "Git global configuration removed"
    }
}

function Reset-GitConfig {
    Write-StepHeader 6 6 "Cleaning up Git configuration..."

    $gitconfigPath = "$env:USERPROFILE\.gitconfig"
    if (Test-Path $gitconfigPath) {
        Remove-Item -Path $gitconfigPath -Force -ErrorAction SilentlyContinue
        Write-Success "Git global config (.gitconfig) removed"
    }
    else {
        Write-Skip "No .gitconfig found"
    }
}

# ============================================================
# Main Uninstall Flow
# ============================================================

try {
    # Check admin privileges
    if (-not (Test-Administrator)) {
        Request-AdminPrivileges -ScriptPath $MyInvocation.MyCommand.Path
        return
    }

    $Host.UI.RawUI.WindowTitle = "Claude Code Uninstaller"
    Clear-Host

    Write-ColoredOutput "========================================" "Red"
    Write-ColoredOutput "   Claude Code One-Click Uninstaller    " "Red"
    Write-ColoredOutput "========================================" "Red"
    Write-ColoredOutput ""
    Write-ColoredOutput "This will uninstall: VS Code, Git, Node.js (nvm), and Claude Code" "White"
    Write-ColoredOutput "WARNING: This will also remove VS Code settings, extensions, and Git config." "Yellow"
    Write-ColoredOutput ""

    # Confirm with user
    $response = Read-Host "Are you sure you want to uninstall everything? [y/N]"
    if ($response -notin @("y", "Y", "yes", "YES")) {
        Write-ColoredOutput "Uninstall cancelled." "Yellow"
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 0
    }

    Write-ColoredOutput ""

    # Uninstall in reverse order of installation
    Uninstall-ClaudeCode        # Step 1 - Remove Claude Code first (depends on npm)
    Uninstall-VSCodeExtensions  # Step 2 - Remove extensions before VS Code
    Uninstall-VSCode            # Step 3 - Remove VS Code
    Uninstall-NodeJS            # Step 4 - Remove Node.js and nvm
    Uninstall-Git               # Step 5 - Remove Git
    Reset-GitConfig             # Step 6 - Clean up Git config

    # Summary
    Write-Host ""
    Write-ColoredOutput "========================================" "Green"
    Write-ColoredOutput "       Uninstall Complete!              " "Green"
    Write-ColoredOutput "========================================" "Green"
    Write-Host ""
    Write-ColoredOutput "All tools have been uninstalled." "White"
    Write-ColoredOutput "You may need to restart your computer for all changes to take effect." "Yellow"
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Host ""
    Write-ColoredOutput "========================================" "Red"
    Write-ColoredOutput "       Uninstall Failed                " "Red"
    Write-ColoredOutput "========================================" "Red"
    Write-Host ""
    Write-ColoredOutput "Error: $($_.Exception.Message)" "Red"

    if ($Debug) {
        Write-ColoredOutput "Stack trace: $($_.ScriptStackTrace)" "Gray"
    }

    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

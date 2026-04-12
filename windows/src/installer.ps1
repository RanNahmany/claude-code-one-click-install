# Claude Code Windows Installer
# This script installs Claude Code and its dependencies on Windows systems
#
# Usage:
#   installer.ps1                    # Interactive installation with user prompts
#   installer.ps1 -Debug             # Enable debug output for troubleshooting

param(
    [switch]$Debug
)

# Load configuration from config.json
function Get-InstallerConfig {
    $configPath = Join-Path $PSScriptRoot "config.json"
    Write-DebugOutput "Looking for config file at: $configPath"
    
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }
    Write-DebugOutput "Config file found, parsing JSON..."

    try {
        $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-DebugOutput "Config loaded successfully"
        if ($Debug) {
            Write-DebugOutput "Node.js version: $($configContent.dependencies.nodejs.version)"
            Write-DebugOutput "Git version: $($configContent.dependencies.git.version)"
            Write-DebugOutput "Context menu icon: $($configContent.installer.contextMenuIcon)"
        }
        return $configContent
    }
    catch {
        throw "Failed to parse configuration file: $($_.Exception.Message)"
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to restart script with admin privileges
function Request-AdminPrivileges {
    param([string]$ScriptPath)

    Write-Host "Admin permissions are needed to install system tools. Please click 'Yes' on the prompt." -ForegroundColor Yellow
    Write-DebugOutput "Current script path: $ScriptPath"
    Write-DebugOutput "Current working directory: $(Get-Location)"
    Write-DebugOutput "Debug mode enabled: $Debug"
    Start-Sleep -Seconds 2

    try {
        # Build arguments including debug parameter if enabled
        $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
        if ($Debug) {
            $arguments += "-Debug"
            Write-DebugOutput "Adding -Debug parameter to elevated process"
        }
        
        Write-DebugOutput "Starting elevated process with arguments: $($arguments -join ' ')"
        
        # Note: -NoExit removed because batch file handles window pause at end
        
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

# Function to write colored output
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to write debug output when -Debug parameter is enabled
# Only outputs messages when script is run with -Debug switch
# Prefixes all messages with [DEBUG] for easy identification
function Write-DebugOutput {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )
    if ($Debug) {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Color
    }
}

# Function to prompt user for yes/no confirmation
function Get-UserConfirmation {
    param(
        [string]$Message,
        [string]$DefaultChoice = "N"
    )

    $defaultText = if ($DefaultChoice.ToUpper() -eq "Y") {
        "default: Yes"
    } else {
        "default: No"
    }

    $prompt = if ($DefaultChoice.ToUpper() -eq "Y") {
        "$Message [Y/n] ($defaultText): "
    } else {
        "$Message [y/N] ($defaultText): "
    }

    do {
        $response = Read-Host $prompt
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $DefaultChoice
            Write-Host "Using default: $($DefaultChoice.ToUpper())" -ForegroundColor Gray
        }
        $response = $response.Trim().ToUpper()
    } while ($response -notin @("Y", "YES", "N", "NO"))

    return $response -in @("Y", "YES")
}

# Function to check Node.js version against minimum requirement
function Test-NodeVersion {
    param([string]$Version)

    try {
        $versionNumber = $Version -replace 'v', ''
        $versionParts = $versionNumber.Split('.')
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        $patch = [int]$versionParts[2]

        # Get minimum version from config
        $minVersion = $script:Config.dependencies.nodejs.minimumVersion
        $minParts = $minVersion.Split('.')
        $minMajor = [int]$minParts[0]
        $minMinor = [int]$minParts[1]
        $minPatch = [int]$minParts[2]

        # Check if version meets minimum requirement
        if ($major -gt $minMajor) { return $true }
        if ($major -eq $minMajor -and $minor -gt $minMinor) { return $true }
        if ($major -eq $minMajor -and $minor -eq $minMinor -and $patch -ge $minPatch) { return $true }

        return $false
    }
    catch {
        return $false
    }
}

# Function to download and install Git
function Install-Git {
    Write-ColoredOutput "A required tool, Git, is missing. We will now install it for you." "Yellow"

    try {
        # Check for running Git processes
        $gitProcesses = Get-Process | Where-Object { $_.ProcessName -like "*git*" -or $_.ProcessName -like "*bash*" }
        if ($gitProcesses.Count -gt 0) {
            Write-ColoredOutput "Warning: Git or Git Bash processes are currently running." "Yellow"
            Write-ColoredOutput "This may interfere with the Git installation." "Yellow"
            Write-ColoredOutput ""
            Write-ColoredOutput "Running processes:" "Gray"
            $gitProcesses | ForEach-Object { Write-ColoredOutput "  - $($_.ProcessName)" "Gray" }
            Write-ColoredOutput ""

            if (-not (Get-UserConfirmation "Continue with Git installation anyway?" "N")) {
                Write-ColoredOutput "Git installation skipped. Please close Git processes and run the installer again." "Yellow"
                return
            }
        }

        # Detect system architecture
        $architecture = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        Write-ColoredOutput "Detected $architecture Windows system" "Gray"

        # Build URL from config template
        $gitConfig = $script:Config.dependencies.git
        $gitUrl = $script:Config.urls.gitBase -replace '{version}', $gitConfig.version -replace '{arch}', $architecture
        $gitInstaller = "$env:TEMP\git-installer.exe"

        Write-ColoredOutput "Downloading Git v$($gitConfig.version) for $architecture..." "Cyan"
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing

        Write-ColoredOutput "Installing Git..." "Cyan"
        Write-ColoredOutput "Note: If installation fails, close all Git Bash windows and try again." "Gray"

        $installProcess = Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait -PassThru

        if ($installProcess.ExitCode -ne 0) {
            throw "Git installer failed with exit code $($installProcess.ExitCode). This often happens when Git processes are running."
        }

        # Add Git to PATH for current session
        $gitPath = if ($architecture -eq "64-bit") {
            "C:\Program Files\Git\bin"
        } else {
            "C:\Program Files (x86)\Git\bin"
        }

        if (Test-Path $gitPath) {
            $env:Path += ";$gitPath"
        }

        Remove-Item $gitInstaller -Force
        Write-ColoredOutput "Git v$($gitConfig.version) installed successfully!" "Green"
    }
    catch {
        Write-ColoredOutput "Git installation failed: $($_.Exception.Message)" "Red"
        Write-ColoredOutput ""
        Write-ColoredOutput "Common solutions:" "Yellow"
        Write-ColoredOutput "- Close all Git Bash windows and terminals" "White"
        Write-ColoredOutput "- Close any applications using Git (VS Code, etc.)" "White"
        Write-ColoredOutput "- Restart your computer and try again" "White"
        Write-ColoredOutput ""

        if (Get-UserConfirmation "Would you like to continue without reinstalling Git?" "N") {
            Write-ColoredOutput "Continuing with existing Git installation..." "Yellow"
        } else {
            throw "Git installation required but failed."
        }
    }
}

# Function to download and install Node.js via nvm-windows
function Install-NodeJS {
    Write-ColoredOutput "A required tool, Node.js, is missing or outdated. We will install it using nvm for better version management." "Yellow"

    try {
        # First, install nvm-windows
        Write-ColoredOutput "Installing nvm-windows (Node Version Manager)..." "Cyan"

        $nvmUrl = $script:Config.urls.nvmWindows
        $nvmInstaller = "$env:TEMP\nvm-setup.exe"

        Write-ColoredOutput "Downloading nvm-windows..." "Cyan"
        Invoke-WebRequest -Uri $nvmUrl -OutFile $nvmInstaller -UseBasicParsing

        Write-ColoredOutput "Installing nvm-windows..." "Cyan"
        Start-Process -FilePath $nvmInstaller -ArgumentList "/S" -Wait

        # Add nvm to PATH for current session
        $nvmPath = "$env:APPDATA\nvm"
        if (Test-Path $nvmPath) {
            $env:Path += ";$nvmPath"
        }

        # Refresh environment variables
        $env:NVM_HOME = "$env:APPDATA\nvm"
        $env:NVM_SYMLINK = "$env:ProgramFiles\nodejs"

        Remove-Item $nvmInstaller -Force

        # Wait a moment for installation to complete
        Start-Sleep -Seconds 3

        # Now install Node.js using version from config
        $nodeConfig = $script:Config.dependencies.nodejs
        $nodeVersion = $nodeConfig.version
        Write-ColoredOutput "Installing Node.js v$nodeVersion using nvm..." "Cyan"

        # Use cmd to run nvm commands (nvm-windows is a batch script)
        $nvmExe = "$env:APPDATA\nvm\nvm.exe"
        if (-not (Test-Path $nvmExe)) {
            # Fallback path
            $nvmExe = "C:\ProgramData\nvm\nvm.exe"
        }

        if (Test-Path $nvmExe) {
            # Install Node.js from config
            Start-Process -FilePath $nvmExe -ArgumentList "install", $nodeVersion -Wait -NoNewWindow

            # Set as default version
            Start-Process -FilePath $nvmExe -ArgumentList "use", $nodeVersion -Wait -NoNewWindow

            # Add Node.js to PATH for current session
            $nodeSymlink = "$env:ProgramFiles\nodejs"
            if (Test-Path $nodeSymlink) {
                $env:Path += ";$nodeSymlink"
            }
        } else {
            throw "nvm installation failed - executable not found"
        }

        Write-ColoredOutput "Node.js v$nodeVersion installed successfully via nvm!" "Green"
        Write-ColoredOutput "You can now use 'nvm list' and 'nvm use <version>' to manage Node.js versions." "Gray"
    }
    catch {
        throw "Failed to install Node.js via nvm: $($_.Exception.Message)"
    }
}

# Function to install Claude Code
function Install-ClaudeCode {
    Write-ColoredOutput "Installing Claude Code..." "Cyan"

    try {
        $result = npm install -g @anthropic-ai/claude-code 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed with exit code $LASTEXITCODE"
        }
        Write-ColoredOutput "Claude Code installed successfully!" "Green"
    }
    catch {
        throw "Failed to install Claude Code: $($_.Exception.Message)"
    }
}

# Function to copy custom icon to permanent location for context menu integration
# Copies claude-color.ico from assets/ to %APPDATA%\ClaudeCode\ for persistent storage
# Returns: $true if successful, $false if icon file missing or copy fails
function Install-ContextMenuIcon {
    try {
        $contextConfig = $script:Config.installer
        $iconSourceFile = $contextConfig.iconSourceFile

        # Create ClaudeCode directory in AppData
        $claudeCodeDir = "$env:APPDATA\ClaudeCode"
        if (-not (Test-Path $claudeCodeDir)) {
            New-Item -ItemType Directory -Path $claudeCodeDir -Force | Out-Null
        }

        # Find the icon file in assets directory
        $assetsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "assets"
        $iconSourcePath = Join-Path $assetsDir $iconSourceFile

        if (-not (Test-Path $iconSourcePath)) {
            Write-ColoredOutput "Warning: Icon file not found at $iconSourcePath, using default icon" "Yellow"
            return $false
        }

        # Copy icon to permanent location
        $iconDestPath = Join-Path $claudeCodeDir $iconSourceFile
        Copy-Item -Path $iconSourcePath -Destination $iconDestPath -Force

        Write-ColoredOutput "Icon installed to: $iconDestPath" "Gray"
        return $true
    }
    catch {
        Write-ColoredOutput "Warning: Could not install custom icon: $($_.Exception.Message)" "Yellow"
        return $false
    }
}

# Function to check if Atlassian MCP server is already configured in Claude Code
# Executes 'claude mcp list' via Git Bash and searches for 'atlassian' in output
# Returns: $true if Atlassian MCP server found, $false otherwise
function Test-AtlassianMCP {
    try {
        # Find Git Bash path
        $bashPath = if (Test-Path "C:\Program Files\Git\bin\bash.exe") {
            "C:\Program Files\Git\bin\bash.exe"
        } elseif (Test-Path "C:\Program Files (x86)\Git\bin\bash.exe") {
            "C:\Program Files (x86)\Git\bin\bash.exe"
        } else {
            return $false
        }

        # Execute claude mcp list and capture output directly
        $mcpListOutput = & $bashPath "-c" "claude mcp list" 2>&1

        # Check if atlassian is in the output
        return ($mcpListOutput -match "atlassian")
    }
    catch {
        return $false
    }
}

# Function to install Atlassian MCP server for Claude Code
# Executes 'claude mcp add --transport sse atlassian -s user https://mcp.atlassian.com/v1/sse' via Git Bash
# Returns: $true if installation successful, $false if failed
function Install-AtlassianMCP {
    Write-ColoredOutput "Installing Atlassian MCP server..." "Cyan"

    try {
        # Find Git Bash path
        $bashPath = if (Test-Path "C:\Program Files\Git\bin\bash.exe") {
            "C:\Program Files\Git\bin\bash.exe"
        } elseif (Test-Path "C:\Program Files (x86)\Git\bin\bash.exe") {
            "C:\Program Files (x86)\Git\bin\bash.exe"
        } else {
            throw "Git Bash not found"
        }

        # Execute the MCP add command directly using PowerShell's & operator
        $mcpCommand = "claude mcp add --transport sse atlassian -s user https://mcp.atlassian.com/v1/sse"

        Write-ColoredOutput "Running: $mcpCommand" "Gray"

        # Use PowerShell's & operator with proper argument handling
        try {
            $output = & $bashPath "-c" $mcpCommand 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {
                Write-ColoredOutput "Command executed successfully" "Gray"
                $installResult = @{ ExitCode = 0 }
            } else {
                Write-ColoredOutput "Command output: $output" "Red"
                $installResult = @{ ExitCode = $exitCode }
            }
        }
        catch {
            Write-ColoredOutput "Exception during execution: $($_.Exception.Message)" "Red"
            $installResult = @{ ExitCode = 1 }
        }

        if ($installResult.ExitCode -eq 0) {
            Write-ColoredOutput "Atlassian MCP server installed successfully!" "Green"
            return $true
        } else {
            throw "MCP installation failed with exit code $($installResult.ExitCode)"
        }
    }
    catch {
        Write-ColoredOutput "Failed to install Atlassian MCP server: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to add Windows Explorer context menu
function Add-ContextMenu {
    Write-ColoredOutput "Adding convenient right-click option to Windows Explorer..." "Cyan"

    try {
        $contextConfig = $script:Config.installer

        # Install custom icon if available
        $iconInstalled = Install-ContextMenuIcon
        $iconPath = if ($iconInstalled) {
            $contextConfig.contextMenuIcon
        } else {
            "shell32.dll,3"  # Fallback to default folder icon
        }

        # Registry paths for folder context menu
        $folderPath = "HKCU:\Software\Classes\Directory\shell\ClaudeCode"
        $folderCommandPath = "$folderPath\command"

        # Registry paths for folder background context menu
        $backgroundPath = "HKCU:\Software\Classes\Directory\Background\shell\ClaudeCode"
        $backgroundCommandPath = "$backgroundPath\command"

        # Create registry keys for folder context menu
        New-Item -Path $folderPath -Force | Out-Null
        New-Item -Path $folderCommandPath -Force | Out-Null

        # Determine Git Bash path
        $gitBashPath = if (Test-Path "C:\Program Files\Git\bin\bash.exe") {
            "C:\Program Files\Git\bin\bash.exe"
        } elseif (Test-Path "C:\Program Files (x86)\Git\bin\bash.exe") {
            "C:\Program Files (x86)\Git\bin\bash.exe"
        } else {
            # Fallback to PowerShell if Git Bash not found
            "powershell.exe"
        }

        if ($gitBashPath -like "*bash.exe") {
            # Use Git Bash - let it handle the directory change natively
            $commandValue = "`"$gitBashPath`" --cd=`"%V`" -c `"claude`""
        } else {
            # Fallback to PowerShell
            $commandValue = 'powershell.exe -NoExit -Command "Set-Location -Path ''%V''; claude"'
        }

        # Set values for folder context menu
        Set-ItemProperty -Path $folderPath -Name "(Default)" -Value $contextConfig.contextMenuText
        Set-ItemProperty -Path $folderPath -Name "Icon" -Value $iconPath
        Set-ItemProperty -Path $folderCommandPath -Name "(Default)" -Value $commandValue

        # Create registry keys for folder background context menu
        New-Item -Path $backgroundPath -Force | Out-Null
        New-Item -Path $backgroundCommandPath -Force | Out-Null

        # Set values for folder background context menu
        Set-ItemProperty -Path $backgroundPath -Name "(Default)" -Value $contextConfig.contextMenuText
        Set-ItemProperty -Path $backgroundPath -Name "Icon" -Value $iconPath
        Set-ItemProperty -Path $backgroundCommandPath -Name "(Default)" -Value $commandValue

        Write-ColoredOutput "Context menu added successfully!" "Green"
    }
    catch {
        throw "Failed to add context menu: $($_.Exception.Message)"
    }
}

# Main installation logic
try {
    Write-DebugOutput "=== Claude Code Installer Started ==="
    Write-DebugOutput "Script path: $($MyInvocation.MyCommand.Path)"
    Write-DebugOutput "Working directory: $(Get-Location)"
    Write-DebugOutput "Debug mode: $Debug"
    Write-DebugOutput "Running as admin: $(Test-Administrator)"
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-DebugOutput "Admin privileges required, requesting elevation..."
        Request-AdminPrivileges -ScriptPath $MyInvocation.MyCommand.Path
        return
    }
    
    Write-DebugOutput "Admin privileges confirmed, continuing with installation..."

    # Load configuration after admin check
    try {
        $script:Config = Get-InstallerConfig
    }
    catch {
        Write-Host "Configuration Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please ensure config.json exists in the src directory and is valid JSON." -ForegroundColor Yellow
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    # Setup environment
    $Host.UI.RawUI.WindowTitle = "Claude Code Installer"
    Clear-Host

    Write-ColoredOutput "========================================" "Magenta"
    Write-ColoredOutput "    Welcome to Claude Code Installer   " "Magenta"
    Write-ColoredOutput "========================================" "Magenta"

    Write-ColoredOutput ""

    # Check dependencies
    Write-ColoredOutput "Checking system requirements..." "Cyan"

    $gitExists = Get-Command git -ErrorAction SilentlyContinue
    $nodeExists = Get-Command node -ErrorAction SilentlyContinue
    $nvmExists = Get-Command nvm -ErrorAction SilentlyContinue
    $nodeVersionOk = $false

    if ($nodeExists) {
        $nodeVersion = node -v
        $nodeVersionOk = Test-NodeVersion $nodeVersion
        if (-not $nodeVersionOk) {
            $minVersion = $script:Config.dependencies.nodejs.minimumVersion
            Write-ColoredOutput "Node.js version $nodeVersion found, but v$minVersion or newer is required." "Yellow"
        }
    } elseif ($nvmExists) {
        # Check if nvm has any Node.js versions installed
        try {
            $nvmList = nvm list 2>$null
            $minMajor = $script:Config.dependencies.nodejs.minimumVersion.Split('.')[0]
            if ($nvmList -match "$minMajor\.\d+\.\d+") {
                $nodeVersionOk = $true
                Write-ColoredOutput "Node.js v$minMajor.x found via nvm." "Green"
            }
        } catch {
            # nvm exists but no suitable Node.js version
        }
    }

    # Install dependencies with user prompts
    Write-ColoredOutput ""

    # Handle Git installation
    if (-not $gitExists) {
        Install-Git
    } else {
        Write-ColoredOutput "Git is already installed." "Green"
        if (Get-UserConfirmation "Would you like to reinstall Git anyway?" "N") {
            Install-Git
        }
    }

    # Handle Node.js/nvm installation
    Write-ColoredOutput ""
    if (-not $nodeExists -and -not $nvmExists) {
        Install-NodeJS
    } elseif (-not $nodeVersionOk) {
        if ($nvmExists) {
            $nodeVersion = $script:Config.dependencies.nodejs.version
            Write-ColoredOutput "nvm is installed but needs Node.js v$nodeVersion." "Yellow"
            if (Get-UserConfirmation "Install Node.js v$nodeVersion via nvm?" "N") {
                # Just install Node.js via existing nvm
                try {
                    $nvmExe = Get-Command nvm -ErrorAction SilentlyContinue
                    if ($nvmExe) {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "nvm", "install", $nodeVersion -Wait -NoNewWindow
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "nvm", "use", $nodeVersion -Wait -NoNewWindow
                        Write-ColoredOutput "Node.js v$nodeVersion installed via existing nvm!" "Green"
                    } else {
                        Install-NodeJS
                    }
                } catch {
                    Install-NodeJS
                }
            }
        } else {
            $minVersion = $script:Config.dependencies.nodejs.minimumVersion
            Write-ColoredOutput "Node.js version $nodeVersion found, but v$minVersion or newer is required." "Yellow"
            if (Get-UserConfirmation "Would you like to reinstall Node.js with nvm-windows?" "N") {
                Install-NodeJS
            }
        }
    } else {
        Write-ColoredOutput "Node.js is already installed and up to date." "Green"
        if (Get-UserConfirmation "Would you like to reinstall Node.js/nvm anyway?" "N") {
            Install-NodeJS
        }
    }

    # Install Claude Code
    Write-ColoredOutput ""

    # Check if Claude Code is already installed
    $claudeExists = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeExists) {
        Install-ClaudeCode
    } else {
        Write-ColoredOutput "Claude Code is already installed." "Green"
        if (Get-UserConfirmation "Would you like to reinstall Claude Code anyway?" "N") {
            Install-ClaudeCode
        }
    }

    # Handle context menu integration
    Write-ColoredOutput ""

    # Check if context menu already exists
    $contextMenuExists = (Test-Path "HKCU:\Software\Classes\Directory\shell\ClaudeCode") -or
                        (Test-Path "HKCU:\Software\Classes\Directory\Background\shell\ClaudeCode")

    $contextMenuAdded = $false

    if ($contextMenuExists) {
        Write-ColoredOutput "Windows Explorer context menu for Claude Code is already installed." "Green"
        Write-ColoredOutput "This adds 'Open with Claude Code' to folder right-click menus." "Gray"

        $userChoice = ""
        do {
            Write-Host "What would you like to do? " -NoNewline
            Write-Host "[K]eep, [U]pdate, or [R]emove? [K/u/r]: " -NoNewline -ForegroundColor Cyan
            $userChoice = Read-Host
            if ([string]::IsNullOrWhiteSpace($userChoice)) {
                $userChoice = "K"
            }
            $userChoice = $userChoice.Trim().ToUpper()
        } while ($userChoice -notin @("K", "KEEP", "U", "UPDATE", "R", "REMOVE"))

        switch ($userChoice) {
            {$_ -in @("K", "KEEP")} {
                Write-ColoredOutput "Keeping existing context menu." "Green"
                $contextMenuAdded = $true
            }
            {$_ -in @("U", "UPDATE")} {
                Write-ColoredOutput "Updating context menu with latest settings..." "Yellow"
                Add-ContextMenu
                $contextMenuAdded = $true
            }
            {$_ -in @("R", "REMOVE")} {
                Write-ColoredOutput "Removing context menu..." "Yellow"
                try {
                    Remove-Item "HKCU:\Software\Classes\Directory\shell\ClaudeCode" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item "HKCU:\Software\Classes\Directory\Background\shell\ClaudeCode" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-ColoredOutput "Context menu removed successfully." "Green"
                }
                catch {
                    Write-ColoredOutput "Warning: Could not fully remove context menu entries." "Yellow"
                }
                $contextMenuAdded = $false
            }
        }
    } else {
        Write-ColoredOutput "The installer can add 'Open with Claude Code' to your Windows Explorer right-click menu." "Cyan"
        Write-ColoredOutput "This allows you to right-click any folder and launch Claude Code directly." "Gray"
        if (Get-UserConfirmation "Would you like to add the context menu option?" "Y") {
            Add-ContextMenu
            $contextMenuAdded = $true
        } else {
            Write-ColoredOutput "Skipping context menu integration." "Yellow"
        }
    }

    # Handle Atlassian MCP server installation
    Write-ColoredOutput ""

    $mcpInstalled = $false
    $atlassianMCPExists = Test-AtlassianMCP

    if ($atlassianMCPExists) {
        Write-ColoredOutput "Atlassian MCP server is already configured." "Green"
        Write-ColoredOutput "This enables Claude Code to access Jira tickets and Confluence pages." "Gray"
        $mcpInstalled = $true
    } else {
        Write-ColoredOutput "The installer can add the Atlassian MCP server to Claude Code." "Cyan"
        Write-ColoredOutput "This enables access to Jira tickets and Confluence pages directly from Claude Code." "Gray"

        if (Get-UserConfirmation "Would you like to add the Atlassian MCP server?" "Y") {
            $mcpInstalled = Install-AtlassianMCP
        } else {
            Write-ColoredOutput "Skipping Atlassian MCP server installation." "Yellow"
            Write-ColoredOutput "You can install it later by running this command in Git Bash:" "Gray"
            Write-ColoredOutput "claude mcp add --transport sse atlassian -s user https://mcp.atlassian.com/v1/sse" "Cyan"
        }
    }

    # Success message
    Write-ColoredOutput ""
    Write-ColoredOutput "========================================" "Green"
    Write-ColoredOutput "    Installation Complete!             " "Green"
    Write-ColoredOutput "========================================" "Green"
    Write-ColoredOutput ""
    Write-ColoredOutput "Claude Code has been successfully installed!" "Green"
    Write-ColoredOutput ""
    Write-ColoredOutput "How to use:" "White"
    if ($contextMenuAdded) {
        Write-ColoredOutput "- Right-click on any project folder and select 'Open with Claude Code'" "White"
        Write-ColoredOutput "- Or open Git Bash and type 'claude'" "White"
    } else {
        Write-ColoredOutput "- Open Git Bash, navigate to your project folder, and type 'claude'" "White"
        Write-ColoredOutput "- Or run 'claude' from any directory to start in the current location" "White"
    }
    Write-ColoredOutput ""
    Write-ColoredOutput "Important:" "Yellow"
    Write-ColoredOutput "The first time you open Claude Code, you'll be asked to select a color theme and authenticate." "Yellow"
    Write-ColoredOutput "Select #2 'Billing Account'. Your browser will open to login, use your Orases Google account to authenticate." "Yellow"
    if ($mcpInstalled) {
        Write-ColoredOutput ""
        Write-ColoredOutput "You'll also be asked to authenticate with Atlassian to enable Jira and Confluence access." "Yellow"
        Write-ColoredOutput "After opening claude, type `/mcp` and hit Enter" "Yellow"
    }
    Write-ColoredOutput ""
    Write-ColoredOutput "Press any key to exit..." "White"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-DebugOutput "Installation failed with error: $($_.Exception.Message)"
    Write-DebugOutput "Stack trace: $($_.ScriptStackTrace)"
    
    Write-ColoredOutput ""
    Write-ColoredOutput "========================================" "Red"
    Write-ColoredOutput "    Installation Failed                " "Red"
    Write-ColoredOutput "========================================" "Red"
    Write-ColoredOutput ""
    Write-ColoredOutput "Error: $($_.Exception.Message)" "Red"
    
    if ($Debug) {
        Write-ColoredOutput ""
        Write-ColoredOutput "Debug Information:" "Yellow"
        Write-ColoredOutput "Stack trace: $($_.ScriptStackTrace)" "Gray"
        Write-ColoredOutput "Error details: $($_.Exception | Format-List * | Out-String)" "Gray"
    }
    
    Write-ColoredOutput ""
    Write-ColoredOutput "Please check your internet connection and try again." "Yellow"
    Write-ColoredOutput "If the problem persists, please visit:" "Yellow"
    Write-ColoredOutput "https://github.com/anthropics/claude-code/issues" "Cyan"
    Write-ColoredOutput ""
    Write-ColoredOutput "Press any key to exit..." "White"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

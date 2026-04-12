# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Windows installer for Claude Code that provides a one-click installation experience. The project consists of PowerShell scripts, batch files, and JSON configuration to automatically install Claude Code and its dependencies on Windows systems.

## Architecture

### Core Components

1. **Smart Batch Launcher** (`install.bat`)
   - Entry point for users with intelligent file detection
   - Auto-downloads installer files from GitHub if not found locally
   - Supports both cloned repository and single-command installation
   - Provides Windows-native experience with comprehensive error handling

2. **PowerShell Installer** (`src/installer.ps1`)
   - Main installation logic with enhanced user experience
   - Admin privilege management and self-elevation
   - Dependency detection and installation (Git, Node.js, Claude Code)
   - Atlassian MCP server integration via Git Bash execution
   - Custom icon installation and Windows Explorer context menu setup
   - Enhanced error handling and user feedback with clear prompts

3. **Configuration File** (`src/config.json`)
   - Version management for dependencies (Node.js, Git)
   - URL templates for downloads with architecture detection
   - Custom icon configuration and UI customization settings
   - Centralized configuration for easy maintenance

4. **Custom Assets** (`assets/claude-color.ico`)
   - Custom icon for Windows Explorer context menu integration
   - Automatically deployed to user's AppData directory during installation

### Key Design Decisions

#### nvm-windows Over MSI
- **Chosen**: nvm-windows for Node.js installation
- **Rationale**: Provides version management capabilities, avoids conflicts with future nvm usage
- **Trade-off**: Slightly more complex installation but much better developer experience

#### Configuration-Driven Architecture
- **Pattern**: JSON configuration file controls all versions and URLs
- **Benefits**: Easy updates without code changes, maintainable by non-developers
- **Implementation**: Template URLs with `{version}` and `{arch}` placeholders

#### Architecture Detection
- **Method**: `[Environment]::Is64BitOperatingSystem` for system detection
- **Coverage**: Handles both 32-bit and 64-bit Windows installations
- **Fallback**: Different installation paths and download URLs per architecture

#### Smart Local/Remote Detection
- **Pattern**: Batch file checks for local `src/installer.ps1` and `src/config.json` presence
- **Benefits**: Works seamlessly with cloned repositories and single-command downloads
- **Implementation**: Uses `%~dp0` to detect script directory and conditional file existence checks

#### Atlassian MCP Server Integration
- **Chosen**: PowerShell calling Git Bash via `& $bashPath "-c" $command` pattern
- **Rationale**: Enables Claude Code MCP commands from PowerShell installer context
- **Trade-off**: Requires Git Bash installation but provides native claude command execution

#### Custom Icon Deployment
- **Method**: Copy assets to `%APPDATA%\ClaudeCode\` during installation
- **Benefits**: Persistent icon location independent of installer source
- **Fallback**: Uses `shell32.dll,3` if custom icon deployment fails

#### Dual-Method Download System
- **Primary**: curl with verbose debugging and comprehensive error detection
- **Fallback**: PowerShell Invoke-WebRequest when curl unavailable or fails
- **Detection**: Automatic availability checking with graceful degradation
- **Benefits**: Works across different Windows configurations and corporate environments

## Development Patterns

### Error Handling Strategy
```powershell
try {
    # Installation logic
    Write-ColoredOutput "Success message" "Green"
} catch {
    throw "Failed to install X: $($_.Exception.Message)"
}
```

### Configuration Access Pattern
```powershell
$script:Config = Get-InstallerConfig
$version = $script:Config.dependencies.nodejs.version
```

### Interactive Prompt Implementation
- **Pattern**: User-friendly confirmation prompts with clear defaults
- **Usage**: `Get-UserConfirmation` function with default choices and visual indicators
- **Enhanced UX**: Shows `(default: Yes/No)` and confirms when default is used
- **Logic**: Conditional flows based on user responses with sensible defaults

### Cross-Platform Command Execution
- **Pattern**: PowerShell executing Git Bash commands for Claude Code integration
- **Implementation**: `& $bashPath "-c" $command` with proper error handling
- **Usage**: MCP server management and Claude Code command execution
- **Error Handling**: Capture exit codes and output for user feedback

### Asset Management Pattern
- **Strategy**: Copy assets to permanent user-specific locations during installation
- **Location**: `%APPDATA%\ClaudeCode\` for persistent storage
- **Benefits**: Survives installer cleanup and system updates
- **Fallback**: Graceful degradation to system defaults if deployment fails

### Debug Mode Implementation
- **Pattern**: Command-line parameter passed through entire execution chain
- **Usage**: `install.bat -debug` enables comprehensive troubleshooting output
- **Scope**: Debug information flows from batch → PowerShell → elevated PowerShell
- **Benefits**: Provides detailed diagnostics for download, path, and execution issues

### Variable Expansion in Batch Files
- **Pattern**: Consistent use of delayed expansion (`!variable!`) for dynamic values
- **Challenge**: Mixed regular (`%variable%`) and delayed expansion in same script
- **Solution**: Set critical variables globally, use delayed expansion for all dynamic operations
- **Example**: `REPO_BASE` set once, used with `!REPO_BASE!/path/file.ext`

## Common Issues and Solutions

### Admin Privilege Management
- **Issue**: PowerShell scripts need elevation for system changes
- **Solution**: Auto-detection with `Test-Administrator` and self-elevation
- **Pattern**: Restart script with `Start-Process -Verb RunAs`

### PATH Management
- **Issue**: Newly installed tools not available in current session
- **Solution**: Manual PATH updates for current PowerShell session
- **Example**: `$env:Path += ";$nodePath"`

### nvm-windows Integration
- **Issue**: nvm-windows uses batch scripts, not PowerShell cmdlets
- **Solution**: Shell out to cmd.exe for nvm commands
- **Pattern**: `Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "nvm", "install", $version`

### Git Bash Command Execution from PowerShell
- **Issue**: Complex commands with arguments not properly passed to bash from PowerShell
- **Solution**: Use PowerShell's `&` operator with proper argument separation
- **Pattern**: `& $bashPath "-c" $command` instead of `Start-Process` with complex arguments
- **Debugging**: Capture both stdout and stderr with `2>&1` for troubleshooting

### Custom Icon Installation
- **Issue**: Icons need persistent storage location for context menu registry entries
- **Solution**: Deploy to `%APPDATA%\ClaudeCode\` during installation
- **Fallback**: Use `shell32.dll,3` if custom icon deployment fails
- **Registry**: Update both folder and background context menu entries with same icon path

### Download Failures and Variable Expansion
- **Issue**: Batch file variables not expanding properly, causing incomplete URLs
- **Root Cause**: Mixing regular (`%var%`) and delayed expansion (`!var!`) inconsistently
- **Solution**: Set global variables early, use delayed expansion throughout execution
- **Debug Pattern**: `install.bat -debug` shows variable values and URL construction

### Directory Creation and File Writing
- **Issue**: curl fails to write files because destination directories don't exist
- **Solution**: Create full directory structure before downloading files
- **Pattern**: `mkdir "!TEMP_DIR!\subdir" 2>nul` with error suppression
- **Verification**: Debug mode shows directory creation success/failure

### PowerShell Admin Elevation with Parameters
- **Issue**: Debug parameters lost when PowerShell elevates to admin privileges
- **Solution**: Preserve command-line arguments through elevation process
- **Pattern**: Build argument array dynamically and pass to elevated process
- **Debug**: Use `-NoExit` in debug mode to prevent window closure for troubleshooting

## Testing Approach

### Interactive Testing
- Run installer with existing dependencies to test prompts and default behaviors
- Test "reinstall anyway" choices for each component (Git, Node.js, Claude Code)
- Verify context menu Keep/Update/Remove functionality
- Test Atlassian MCP server installation and detection
- Verify custom icon installation and fallback behavior

### Local vs Remote Installation Testing
- Test with cloned repository (local files present)
- Test with single-command download (no local files)
- Verify smart detection messages and file usage
- Test cleanup behavior in download mode vs local mode

### Configuration Testing
- Modify `config.json` to test different versions
- Invalid JSON testing for error handling
- URL template testing with different architectures
- Test icon path configuration and asset deployment

### MCP Integration Testing
- Test MCP server detection with existing installations
- Verify `claude mcp list` command execution from PowerShell
- Test MCP installation command with various Git Bash paths
- Validate error handling when Git Bash is not available

### Debug Mode Testing
- Test `install.bat -debug` with network failures to verify error diagnostics
- Verify debug parameter preservation through admin elevation
- Test variable expansion debugging with different Windows versions
- Validate PowerShell window behavior in debug mode (stays open with `-NoExit`)
- Test download fallback scenarios (curl → PowerShell) in debug mode

## File Structure Rationale

```
├── install.bat                              # Smart installer entry point with auto-download
├── src/                                     # Source code isolation  
│   ├── installer.ps1                        # Main logic with MCP integration
│   └── config.json                          # Configuration data with icon settings
├── assets/                                  # Static assets for deployment
│   └── claude-color.ico                     # Custom context menu icon
├── README.md                                # User documentation with installation methods
├── LICENSE                                  # Legal requirements
└── CLAUDE.md                               # Development documentation
```

## Installation Modes

The installer supports three distinct installation modes with automatic detection:

### 1. Single-Command Installation
- **Trigger**: User runs curl command to download and execute `install.bat`
- **Behavior**: Downloads all required files from GitHub to temp directory
- **Cleanup**: Automatically removes temporary files after installation
- **Use case**: Quick installation without repository access

### 2. Cloned Repository Installation  
- **Trigger**: Local `src/installer.ps1` and `src/config.json` files exist
- **Behavior**: Uses local files directly, no downloads required
- **Cleanup**: No cleanup needed, preserves local repository structure
- **Use case**: Development, code review, or offline installation

### 3. Manual Download Installation
- **Trigger**: Repository downloaded as ZIP and extracted
- **Behavior**: Same as cloned repository mode (uses local files)
- **Cleanup**: No cleanup needed
- **Use case**: Users who prefer manual file management

## Security Considerations

### Admin Privilege Usage
- **Scope**: Only requested when needed for system modifications
- **Justification**: Required for program installation and registry modifications
- **Mitigation**: Clear user prompts explaining why elevation is needed

### Download Security
- **Sources**: Only official GitHub releases and nodejs.org
- **Verification**: HTTPS-only downloads
- **Execution**: Downloaded files executed with known safe parameters

## Maintenance Guidelines

### Version Updates
1. Edit `src/config.json` version numbers
2. Test by running installer and choosing to reinstall components
3. No code changes required for routine updates

### URL Updates
- Update template URLs in config.json if GitHub/Node.js change release patterns
- Test with both 32-bit and 64-bit placeholder values

### Adding New Dependencies
1. Add to `dependencies` section in config.json
2. Create `Install-X` function following existing patterns
3. Add detection logic in main installation flow
4. Update README.md with new dependency information

## Build and Test Commands

Since this is a PowerShell/batch project, there are no traditional build commands. Testing is done by:

```powershell
# Test local installation (cloned repository mode)
.\install.bat

# Test single-command installation (download mode)
curl -L "https://raw.githubusercontent.com/nitromike502/claude-code-windows-installer/main/install.bat" -o test-install.bat && test-install.bat

# Test single-command installation with debug mode
curl -L "https://raw.githubusercontent.com/nitromike502/claude-code-windows-installer/main/install.bat" -o test-install.bat && test-install.bat -debug

# Test interactive installation with existing dependencies
.\src\installer.ps1

# Test with debug mode enabled
.\install.bat -debug
.\src\installer.ps1 -Debug

# Comprehensive testing scenarios:
# - Test with/without existing Git installation
# - Test with/without existing Node.js/nvm
# - Test with/without existing Claude Code
# - Test with/without existing Atlassian MCP server
# - Test context menu: Keep/Update/Remove options
# - Test custom icon installation and fallback behavior
# - Test different user response patterns and defaults
# - Test debug mode with network failures and path issues
# - Test admin elevation parameter preservation
```
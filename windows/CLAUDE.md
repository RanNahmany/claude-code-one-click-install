# CLAUDE.md

## Project Overview

Windows one-click installer for Claude Code. Installs VS Code, Git, Node.js (via nvm-windows), and Claude Code with zero manual steps. No interactive prompts — fully automatic with skip-if-installed behavior.

## Architecture

### Entry Point: `install.bat`
- Detects local vs remote mode (checks for `src/installer.ps1` and `src/config.json`)
- Remote mode: downloads files from GitHub to temp directory, cleans up after
- Local mode: runs directly from cloned repo
- Supports `-debug` flag passed through to PowerShell

### Main Logic: `src/installer.ps1`
- Requests admin elevation if needed (via `Start-Process -Verb RunAs`)
- Loads config from `src/config.json`
- Runs 8 installation steps sequentially, each with skip-if-installed checks
- Displays verification summary at the end

### Configuration: `src/config.json`
- VS Code settings and extensions list
- Git global config key-value pairs
- Minimum version requirements for Node.js and Git
- Download URLs for nvm-windows and VS Code

## Installation Flow

1. Install VS Code (winget, fallback to direct download)
2. Install Git (winget, fallback to direct download)
3. Configure Git global settings
4. Install nvm-windows + Node.js LTS
5. Update npm to latest
6. Install Claude Code via npm
7. Install VS Code extensions
8. Configure VS Code settings (merge with existing)

## Key Patterns

- **No interactive prompts**: Skip if installed, no "reinstall?" questions
- **winget + fallback**: Try winget first for VS Code/Git, fall back to direct download
- **Config-driven**: All settings in JSON, no hardcoded values in scripts
- **PATH management**: Add newly installed tools to `$env:Path` for current session
- **VS Code settings merge**: Don't overwrite user's existing settings, only add/override configured keys

## Testing

```powershell
# Local mode
.\install.bat
.\install.bat -debug

# Direct PowerShell
.\src\installer.ps1
.\src\installer.ps1 -Debug
```

Test scenarios:
- Clean machine (nothing installed) → everything installs
- Everything already installed → all steps skipped with green checkmarks
- Partial install (e.g., Git but no VS Code) → installs missing tools only

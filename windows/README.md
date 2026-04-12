# Claude Code One-Click Installer — Windows

Automated installer that sets up VS Code, Git, Node.js, and Claude Code on Windows with zero manual steps.

## Quick Start

**One-line install** (open PowerShell as Administrator):
```powershell
irm "https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/windows/install.bat" -OutFile install.bat; .\install.bat
```

**Or clone and run:**
```
git clone https://github.com/RanNahmany/claude-code-one-click-install.git
cd claude-code-one-click-install\windows
install.bat
```

## What It Does

1. **VS Code** — Installs via winget (fallback: direct download), adds to PATH
2. **Git** — Installs via winget (fallback: direct download), adds to PATH
3. **Git Config** — Sets default branch to `main`, editor to VS Code, credential helper
4. **Node.js** — Installs nvm-windows, then Node.js LTS via nvm
5. **npm** — Updates to latest version
6. **Claude Code** — Installs globally via npm
7. **VS Code Extensions** — Installs Claude Code extension
8. **VS Code Settings** — Configures auto-save, font size, formatting, etc.

## Requirements

- Windows 10 or Windows 11
- Internet connection
- Admin privileges (script will request elevation automatically)

## Debug Mode

Run with debug output for troubleshooting:
```
install.bat -debug
```

## Configuration

Edit `src/config.json` to customize:
- VS Code settings and extensions
- Git global configuration
- Minimum version requirements
- Download URLs

## How It Works

- `install.bat` is the entry point that detects local vs remote mode
- If run from a cloned repo, it uses local files
- If downloaded standalone, it fetches `src/installer.ps1` and `src/config.json` from GitHub
- `src/installer.ps1` does all the actual installation work
- Each step checks if the tool is already installed and skips if so
- No interactive prompts — everything is automatic

## Uninstall

To remove everything that was installed:
```
uninstall.bat
```

This will uninstall VS Code, Git, Node.js (nvm-windows), Claude Code, and clean up all settings/config files. You'll be asked to confirm before proceeding.

## File Structure

```
windows/
├── install.bat            # Entry point launcher
├── uninstall.bat          # Uninstaller launcher
├── src/
│   ├── installer.ps1      # Main PowerShell installer
│   ├── uninstaller.ps1    # Main PowerShell uninstaller
│   └── config.json        # Configuration
├── README.md              # This file
├── CLAUDE.md              # Development documentation
└── LICENSE                # MIT License
```

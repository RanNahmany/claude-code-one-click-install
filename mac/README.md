# Claude Code One-Click Installer — macOS

Automated installer that sets up VS Code, Git, Node.js, and Claude Code on macOS with zero manual steps.

## Quick Start

**One-line install** (open Terminal):
```bash
curl -fsSL https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/mac/install.sh | bash
```

**Or clone and run:**
```bash
git clone https://github.com/RanNahmany/claude-code-one-click-install.git
cd claude-code-one-click-install/mac
bash install.sh
```

## What It Does

1. **Xcode CLI Tools** — Installs if not present (required for Homebrew/Git)
2. **Homebrew** — Installs the macOS package manager
3. **Git** — Installs via Homebrew
4. **Git Config** — Sets default branch to `main`, editor to VS Code, credential helper
5. **VS Code** — Installs via Homebrew cask, adds `code` command to PATH
6. **nvm** — Installs Node Version Manager
7. **Node.js** — Installs LTS version via nvm
8. **npm** — Updates to latest version
9. **Claude Code** — Installs globally via npm
10. **VS Code Extensions** — Installs Claude Code extension
11. **VS Code Settings** — Configures auto-save, font size, formatting, etc.

## Requirements

- macOS 12 (Monterey) or later
- Internet connection
- Both Apple Silicon (M1/M2/M3/M4) and Intel Macs are supported

## Debug Mode

Run with debug output for troubleshooting:
```bash
bash install.sh --debug
```

Or with the one-liner:
```bash
curl -fsSL https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/mac/install.sh | bash -s -- --debug
```

## Configuration

Edit `src/config.json` to customize:
- VS Code settings and extensions
- Git global configuration
- Minimum version requirements

## How It Works

- `install.sh` is the entry point that detects local vs remote mode
- If run from a cloned repo, it uses local files
- If piped via curl, it downloads `src/installer.sh` and `src/config.json` from GitHub
- `src/installer.sh` does all the actual installation work
- Uses Homebrew as the package manager for Git and VS Code
- Uses nvm for Node.js version management
- Each step checks if the tool is already installed and skips if so
- No interactive prompts — everything is automatic

## Notes

- Homebrew installs to `/opt/homebrew` on Apple Silicon and `/usr/local` on Intel
- The installer adds Homebrew and VS Code to your shell PATH automatically
- nvm is sourced from `~/.nvm/nvm.sh` — this is added to your shell profile automatically
- You may need to open a new terminal window after installation for all PATH changes to take effect

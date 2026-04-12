# Claude Code One-Click Installer

One-click installer scripts that set up a complete Claude Code development environment. Designed for students — run one command, get everything installed with zero manual steps.

## What Gets Installed

| Tool | Description |
|------|-------------|
| **VS Code** | Latest version with auto-save, formatting, and sensible defaults |
| **Claude Code Extension** | Pre-installed in VS Code |
| **Git** | Configured with best practices (default branch: main, VS Code as editor) |
| **Node.js** | Latest LTS version via nvm (with npm updated to latest) |
| **Claude Code** | Latest version via npm |

## Quick Start

### Windows - One-Click install (Recommended)

**Step 1: Open PowerShell as administrator (right-click on PowerShell and select "Run as administrator")**

**Step 2: Copy&Paste the following command into PowerShell and press Enter**
```bash
curl -L "https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/windows/install.bat" -o install.bat && install.bat
```

### macOS - One-Click install (Recommended)

**Step 1: Open Terminal**

**Step 2: Copy&Paste the following command into Terminal and press Enter**
```bash
curl -fsSL https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/mac/install.sh | bash
```

## After Installation

1. Open a **new terminal window** (to load PATH changes)
2. Open VS Code by typing `code` in terminal
3. Open VS Code's terminal (`Ctrl+`` on Windows, `Cmd+`` on Mac)
4. Type `claude` to start Claude Code
5. You'll be prompted to authenticate on first run

## Verify Installation

Run these commands to verify everything is installed:

```bash
code --version
git --version
node --version
npm --version
claude --version
```

## Features

- **Zero prompts** — fully automatic, skips already-installed tools
- **Idempotent** — safe to run multiple times
- **Smart detection** — checks existing installations before installing
- **Progress display** — green checkmarks for each completed step
- **Debug mode** — add `--debug` flag for troubleshooting

## Troubleshooting

### Windows
- Run with debug mode: `install.bat -debug`
- Ensure you have internet access
- If winget is not available, the installer falls back to direct downloads

### macOS
- Run with debug mode: `curl -fsSL ... | bash -s -- --debug`
- If Xcode CLI tools prompt appears, click "Install" and wait
- If Homebrew asks for your password, enter your Mac login password
- Apple Silicon (M1/M2/M3) and Intel Macs are both supported

## Platform Details

- [Windows README](windows/README.md)
- [macOS README](mac/README.md)

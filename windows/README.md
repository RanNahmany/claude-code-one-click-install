# Claude Code Windows Installer

A one-click installer for [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) on Windows systems. This installer automatically handles all dependencies and provides a seamless installation experience for Windows users.

## What It Does

This installer automatically sets up everything you need to run Claude Code on Windows:

- **Installs Claude Code** via npm (`@anthropic-ai/claude-code`)
- **Manages dependencies** - Downloads and installs Git and Node.js if needed
- **Sets up version management** - Installs nvm-windows for better Node.js handling
- **Adds Windows integration** - Creates right-click context menu for folders
- **Handles permissions** - Automatically requests admin privileges when needed
- **Interactive prompts** - User-friendly prompts for all installation decisions

After installation, you can right-click any folder and select "Open with Claude Code" or run `claude` from any command prompt.

## Quick Install

### 🚀 One-Command Installation (Fastest)

Open **Command Prompt** or **PowerShell** as Administrator and run:

```cmd
curl -L "https://raw.githubusercontent.com/nitromike502/claude-code-windows-installer/main/install.bat" -o install.bat && install.bat
```

This single command will:
- Download the installer automatically
- Fetch all required files from the repository  
- Run the complete installation process
- Clean up temporary files when done

**For troubleshooting download issues:**
```cmd
curl -L "https://raw.githubusercontent.com/nitromike502/claude-code-windows-installer/main/install.bat" -o install.bat && install.bat -debug
```

Debug mode provides detailed information about downloads, file paths, and installation steps.

### 📂 Clone Repository Method (For Development/Review)

If you want to review the code or contribute:

```cmd
git clone https://github.com/nitromike502/claude-code-windows-installer.git
cd claude-code-windows-installer
```

Then double-click `install.bat` or run it from command line.

For debugging: `install.bat -debug`

**Smart Detection**: The installer automatically detects if you're running from a cloned repo and uses local files instead of downloading them.

### 📁 Manual Download Method

**For those who prefer downloading manually:**
1. Download the repository as ZIP from GitHub
2. Extract the files to your Windows machine
3. Double-click `install.bat`
4. Click "Yes" when prompted for admin privileges
5. Answer the interactive prompts for your preferences
6. Wait for installation to complete

## Features

- ✅ **Single-command installation** - One curl command downloads and runs everything
- ✅ **Smart local detection** - Automatically uses local files if repository is cloned
- ✅ **Comprehensive debug mode** - Detailed troubleshooting for download and installation issues
- ✅ **Dual-download fallback** - Automatically switches from curl to PowerShell if needed
- ✅ **Automatic dependency management** - Installs Git and Node.js if missing
- ✅ **Smart version detection** - Uses nvm-windows for better Node.js version management
- ✅ **Architecture aware** - Automatically detects 32-bit vs 64-bit Windows
- ✅ **Windows Explorer integration** - Adds right-click context menu for folders
- ✅ **Admin privilege handling** - Automatically requests elevation when needed
- ✅ **Interactive prompts** - User-friendly choices for all installation decisions
- ✅ **Configuration-driven** - Easy to update versions without code changes

## Troubleshooting

### Debug Mode

If you encounter download failures or other installation issues, enable debug mode:

```cmd
install.bat -debug
```

Debug mode provides comprehensive troubleshooting information including:
- **Download diagnostics**: Shows URLs, HTTP responses, and file creation status
- **Path resolution**: Displays all file paths and directory operations
- **Variable expansion**: Shows how batch variables are being processed
- **PowerShell execution**: Keeps windows open to see detailed error messages
- **Admin privilege flow**: Tracks elevation process and parameter passing

### Common Issues

**Download Failures:**
- Corporate firewalls may block GitHub raw content
- Some Windows systems lack curl (installer automatically falls back to PowerShell)
- SSL/TLS certificate issues in corporate environments

**Admin Privilege Issues:**
- Always run from an Administrator command prompt for best results
- Some antivirus software may interfere with admin elevation

**Network Issues:**
- Check internet connectivity
- Configure proxy settings if behind corporate firewall
- Try running from Git Bash if Command Prompt fails

## Usage

After installation completes:

1. **Verify installation**: Open a new command prompt and run:
   ```cmd
   claude --version
   ```

2. **Start using Claude Code**: 
   - **Via context menu**: Right-click any project folder → "Open with Claude Code" (opens Git Bash)
   - **Via command line**: Navigate to your project and run `claude`

3. **First-time setup**: The first time you run Claude Code, your browser will open asking you to log in. This is normal and only happens once.

## Interactive Installation

The installer uses interactive prompts instead of command-line flags, making it user-friendly:

### Installation Flow
```batch
# Run the installer
"install.bat"
```

The installer will prompt you for decisions:
- **Git already installed?** → Ask to reinstall or keep existing
- **Node.js/nvm present?** → Ask to reinstall, update, or keep existing  
- **Claude Code exists?** → Ask to reinstall or keep existing
- **Context menu setup?** → Ask to add, update, keep, or remove context menu

### PowerShell Direct Usage
```powershell
# Navigate to src folder and run directly
cd src
.\installer.ps1                    # Interactive installation with prompts
```

## Installation Process

The installer performs these steps automatically:

1. **Checks system requirements**
   - Verifies if Git is installed
   - Checks Node.js version (requires v20.11.0+)
   
2. **Installs missing dependencies**
   - Downloads and installs Git if missing
   - Installs nvm-windows for Node.js version management
   - Installs Node.js v20.18.0 via nvm
   
3. **Installs Claude Code**
   - Runs `npm install -g @anthropic-ai/claude-code`
   
4. **Sets up Windows integration** (optional)
   - Adds "Open with Claude Code" to folder context menus (opens Git Bash)

## Architecture

This installer follows a modular, configuration-driven architecture:

### Core Components

- **Batch Launcher**: User-friendly entry point with parameter support
- **PowerShell Installer**: Main logic with admin privilege management
- **JSON Configuration**: Centralized version and URL management
- **Interactive Prompt System**: User-friendly prompts for all installation decisions

### Design Philosophy

- **Transparency**: All source code is readable and reviewable
- **Maintainability**: Versions controlled via JSON configuration, not hardcoded
- **Developer-friendly**: Uses nvm-windows for Node.js version management
- **Windows-native**: Leverages PowerShell and batch files for optimal Windows integration

### Version Strategy

This installer currently supports:
- **Node.js**: v20.18.0 (via nvm-windows for flexibility)
- **Git**: v2.47.1 (architecture-aware downloads)
- **Claude Code**: Latest from npm (@anthropic-ai/claude-code)

### Configuration

The installer behavior is controlled by `src/config.json`:

```json
{
  "dependencies": {
    "nodejs": {
      "version": "20.18.0",          // Version to install
      "minimumVersion": "20.11.0"    // Minimum required version
    },
    "git": {
      "version": "2.47.1",           // Git version to install
      "minimumVersion": "2.0.0"      // Minimum required version
    }
  },
  "installer": {
    "contextMenuText": "Open with Claude Code",  // Right-click menu text
    "contextMenuIcon": "shell32.dll,3"          // Menu icon
  }
}
```

To update versions, simply edit the JSON file - no code changes required.

## Requirements

- **Windows 7 or later** (32-bit or 64-bit)
- **Internet connection** for downloading dependencies
- **Administrator privileges** (requested automatically)

## Troubleshooting

### Installation Fails
- Check internet connection
- Ensure you clicked "Yes" for admin privileges
- Run the installer again and choose to reinstall failed components when prompted

### Context Menu Not Appearing
- Installation requires admin privileges to modify registry
- Try reinstalling with admin privileges

### Node.js Version Issues
- The installer uses nvm-windows for better version management
- You can later use `nvm list` and `nvm use <version>` to switch versions
- Old MSI installations may conflict - uninstall them first

## File Structure

```
claude-code-windows-installer/
├── install.bat                          # Main launcher
├── src/
│   ├── installer.ps1                        # PowerShell installer script
│   └── config.json                          # Configuration file
├── README.md                                # This file
├── LICENSE                                  # MIT License
└── CLAUDE.md                               # Development documentation
```

## Development

This installer is designed for ease of maintenance:

- **Versions** are configured in `config.json`, not hardcoded
- **URLs** use templates with `{version}` and `{arch}` placeholders
- **Architecture detection** works for both 32-bit and 64-bit systems
- **Error handling** provides clear user-friendly messages

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

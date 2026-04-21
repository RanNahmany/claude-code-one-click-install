#!/bin/bash
# Claude Code macOS Installer
# Installs VS Code, Git, Node.js, and Claude Code with zero manual steps
#
# Usage:
#   bash installer.sh                # Standard installation
#   bash installer.sh --debug        # Enable debug output

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
DEBUG_MODE="${DEBUG_MODE:-false}"
STEP_TOTAL=12
CURRENT_STEP=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --debug|-debug) DEBUG_MODE=true ;;
    esac
done

# ============================================================
# Utility Functions
# ============================================================

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "\033[36m[$CURRENT_STEP/$STEP_TOTAL] $1\033[0m"
}

print_success() {
    echo -e "  \033[32m[OK] $1\033[0m"
}

print_skip() {
    echo -e "  \033[33m[SKIP] $1\033[0m"
}

print_error() {
    echo -e "  \033[31m[FAIL] $1\033[0m"
}

print_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "\033[90m[DEBUG] $1\033[0m"
    fi
}

command_exists() {
    command -v "$1" &>/dev/null
}

# Read a value from config.json using python3 (always available on macOS)
config_get() {
    python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
keys = '$1'.split('.')
val = data
for k in keys:
    val = val[k]
if isinstance(val, dict):
    for k, v in val.items():
        print(f'{k}={v}')
elif isinstance(val, list):
    for item in val:
        print(item)
else:
    print(val)
" 2>/dev/null
}

# Compare version strings: returns 0 if $1 >= $2
version_gte() {
    local IFS='.'
    local i ver1=($1) ver2=($2)
    for ((i=0; i<${#ver2[@]}; i++)); do
        local v1=${ver1[i]:-0}
        local v2=${ver2[i]:-0}
        if ((v1 > v2)); then return 0; fi
        if ((v1 < v2)); then return 1; fi
    done
    return 0
}

# ============================================================
# Installation Functions
# ============================================================

install_xcode_cli() {
    print_step "Checking Xcode Command Line Tools..."

    if xcode-select -p &>/dev/null; then
        print_skip "Xcode Command Line Tools already installed"
        return
    fi

    echo "  Installing Xcode Command Line Tools (this may take a few minutes)..."
    echo "  If a dialog box appears, click 'Install' to continue."

    # Trigger the install
    xcode-select --install 2>/dev/null || true

    # Wait for installation to complete
    echo "  Waiting for installation to complete..."
    until xcode-select -p &>/dev/null; do
        sleep 5
    done

    print_success "Xcode Command Line Tools installed"
}

install_homebrew() {
    print_step "Installing Homebrew..."

    if command_exists brew; then
        local brew_version
        brew_version=$(brew --version 2>/dev/null | head -1)
        print_skip "Homebrew is already installed ($brew_version)"
        return
    fi

    echo "  Downloading and installing Homebrew..."
    echo "  You may be prompted for your password."

    # Install Homebrew non-interactively
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH based on architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        # Apple Silicon
        eval "$(/opt/homebrew/bin/brew shellenv)"
        # Add to shell profile if not already there
        if ! grep -q '/opt/homebrew/bin/brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            print_debug "Added Homebrew to ~/.zprofile"
        fi
    else
        # Intel
        eval "$(/usr/local/bin/brew shellenv)"
        if ! grep -q '/usr/local/bin/brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
            print_debug "Added Homebrew to ~/.zprofile"
        fi
    fi

    if command_exists brew; then
        print_success "Homebrew installed"
    else
        print_error "Homebrew installation may have failed"
        echo "  Please restart your terminal and run this script again."
        exit 1
    fi
}

install_git() {
    print_step "Installing Git..."

    if command_exists git; then
        local git_version
        git_version=$(git --version 2>/dev/null)

        # Check if it meets minimum version
        local current_ver
        current_ver=$(echo "$git_version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        local min_ver
        min_ver=$(config_get "dependencies.git.minimumVersion")

        if version_gte "$current_ver" "$min_ver"; then
            print_skip "Git is already installed ($git_version)"
            return
        fi
    fi

    brew install git
    print_success "Git installed ($(git --version 2>/dev/null))"
}

configure_git() {
    print_step "Configuring Git..."

    if ! command_exists git; then
        print_error "Git not found, skipping configuration"
        return
    fi

    # Read git config from config.json and apply each setting
    while IFS='=' read -r key value; do
        print_debug "Setting git config: $key = $value"
        git config --global "$key" "$value"
    done < <(config_get "git.config")

    print_success "Git configured (default branch: main, editor: VS Code)"
}

install_vscode() {
    print_step "Installing VS Code..."

    # Check if already installed
    if [[ -d "/Applications/Visual Studio Code.app" ]] || command_exists code; then
        print_skip "VS Code is already installed"

        # Ensure 'code' is in PATH even if app exists but CLI isn't linked
        if ! command_exists code; then
            local code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
            if [[ -d "$code_bin" ]]; then
                export PATH="$PATH:$code_bin"
                # Add to .zshrc if not present
                if ! grep -q "Visual Studio Code" "$HOME/.zshrc" 2>/dev/null; then
                    echo 'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' >> "$HOME/.zshrc"
                    print_debug "Added VS Code to PATH in ~/.zshrc"
                fi
            fi
        fi
        return
    fi

    brew install --cask visual-studio-code

    # Ensure 'code' command is available
    local code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    if [[ -d "$code_bin" ]]; then
        export PATH="$PATH:$code_bin"
        # Add to .zshrc if not present
        if ! grep -q "Visual Studio Code" "$HOME/.zshrc" 2>/dev/null; then
            echo 'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' >> "$HOME/.zshrc"
        fi
    fi

    if command_exists code; then
        local code_version
        code_version=$(code --version 2>/dev/null | head -1)
        print_success "VS Code $code_version installed"
    else
        print_success "VS Code installed (restart terminal to use 'code' command)"
    fi
}

install_nvm() {
    print_step "Installing nvm (Node Version Manager)..."

    # Check if nvm is already installed
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [[ -d "$NVM_DIR" ]] && [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # Source it for this session
        . "$NVM_DIR/nvm.sh"
        local nvm_version
        nvm_version=$(nvm --version 2>/dev/null)
        print_skip "nvm is already installed (v$nvm_version)"
        return
    fi

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    # Source nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    if command_exists nvm 2>/dev/null || type nvm &>/dev/null; then
        print_success "nvm installed"
    else
        print_error "nvm installation may have failed"
        echo "  Please restart your terminal and run this script again."
        exit 1
    fi
}

install_nodejs() {
    print_step "Installing Node.js..."

    # Source nvm if available
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    # Check if Node.js is already installed and meets minimum version
    if command_exists node; then
        local current_ver
        current_ver=$(node -v 2>/dev/null | sed 's/^v//')
        local min_ver
        min_ver=$(config_get "dependencies.nodejs.minimumVersion")

        if version_gte "$current_ver" "$min_ver"; then
            local npm_ver
            npm_ver=$(npm -v 2>/dev/null)
            print_skip "Node.js v$current_ver is already installed (npm v$npm_ver)"
            return
        fi
        echo "  Node.js v$current_ver found but v$min_ver+ required. Upgrading..."
    fi

    # Install LTS via nvm
    nvm install --lts
    nvm alias default 'lts/*'

    if command_exists node; then
        local node_ver
        node_ver=$(node -v 2>/dev/null)
        print_success "Node.js $node_ver installed via nvm"
    else
        print_success "Node.js LTS installed via nvm"
    fi
}

update_npm() {
    print_step "Updating npm..."

    # Source nvm if available
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    if ! command_exists npm; then
        print_skip "npm not found, skipping update"
        return
    fi

    npm install -g npm@latest &>/dev/null || true
    local npm_ver
    npm_ver=$(npm -v 2>/dev/null)
    print_success "npm updated to v$npm_ver"
}

install_claude_code() {
    print_step "Installing Claude Code..."

    # Source nvm if available
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    if command_exists claude; then
        local claude_ver
        claude_ver=$(claude --version 2>/dev/null)
        print_skip "Claude Code is already installed ($claude_ver)"
        return
    fi

    if ! command_exists npm; then
        print_error "npm is required to install Claude Code but was not found"
        exit 1
    fi

    npm install -g @anthropic-ai/claude-code

    if command_exists claude; then
        local claude_ver
        claude_ver=$(claude --version 2>/dev/null)
        print_success "Claude Code installed ($claude_ver)"
    else
        print_success "Claude Code installed"
    fi
}

install_bun() {
    print_step "Installing Bun..."

    if command_exists bun; then
        local bun_version
        bun_version=$(bun --version 2>/dev/null)
        print_skip "Bun is already installed (v$bun_version)"
        return
    fi

    # Check if ~/.bun exists even if not in PATH yet
    if [[ -x "$HOME/.bun/bin/bun" ]]; then
        export PATH="$HOME/.bun/bin:$PATH"
        local bun_version
        bun_version=$("$HOME/.bun/bin/bun" --version 2>/dev/null)
        print_skip "Bun is already installed (v$bun_version)"
        return
    fi

    echo "  Downloading and installing Bun..."
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 || {
        print_error "Bun installation failed"
        return
    }

    # Source bun for current session
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"

    if [[ -x "$HOME/.bun/bin/bun" ]]; then
        local bun_version
        bun_version=$("$HOME/.bun/bin/bun" --version 2>/dev/null)
        print_success "Bun v$bun_version installed"
    else
        print_error "Bun installation may have failed"
    fi
}

install_vscode_extensions() {
    print_step "Installing VS Code extensions..."

    if ! command_exists code; then
        print_skip "VS Code 'code' command not found, skipping extensions"
        return
    fi

    while IFS= read -r ext; do
        print_debug "Installing extension: $ext"
        code --install-extension "$ext" --force &>/dev/null && \
            print_success "Extension '$ext' installed" || \
            print_error "Failed to install extension '$ext'"
    done < <(config_get "vscode.extensions")
}

configure_vscode_settings() {
    print_step "Configuring VS Code settings..."

    local settings_dir="$HOME/Library/Application Support/Code/User"
    local settings_file="$settings_dir/settings.json"

    # Ensure directory exists
    mkdir -p "$settings_dir"

    # Use python3 to merge settings (preserves existing user settings)
    python3 -c "
import json, os

config_path = '$CONFIG_FILE'
settings_path = '$settings_file'

# Load desired settings from config
with open(config_path) as f:
    config = json.load(f)
desired = config.get('vscode', {}).get('settings', {})

# Load existing settings if they exist
existing = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            content = f.read().strip()
            if content:
                existing = json.loads(content)
    except (json.JSONDecodeError, IOError):
        pass

# Merge: desired settings override, but keep user's other settings
existing.update(desired)

# Write back
with open(settings_path, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
"

    print_success "VS Code settings configured ($settings_file)"
}

# ============================================================
# Main Installation Flow
# ============================================================

main() {
    # Verify config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    print_debug "=== Claude Code Installer Started ==="
    print_debug "Script dir: $SCRIPT_DIR"
    print_debug "Config file: $CONFIG_FILE"

    echo ""
    echo -e "\033[35m========================================\033[0m"
    echo -e "\033[35m   Claude Code One-Click Installer      \033[0m"
    echo -e "\033[35m             for macOS                   \033[0m"
    echo -e "\033[35m========================================\033[0m"
    echo ""
    echo "This will install: VS Code, Git, Node.js, Bun, and Claude Code"
    echo -e "\033[90mExisting installations will be detected and skipped.\033[0m"

    # Run installation steps
    install_xcode_cli          # Step 1
    install_homebrew           # Step 2
    install_git                # Step 3
    configure_git              # Step 4
    install_vscode             # Step 5
    install_nvm                # Step 6
    install_nodejs             # Step 7
    update_npm                 # Step 8
    install_claude_code        # Step 9
    install_bun                # Step 10
    install_vscode_extensions  # Step 11
    configure_vscode_settings  # Step 12

    # ============================================================
    # Verification Summary
    # ============================================================

    echo ""
    echo -e "\033[32m========================================\033[0m"
    echo -e "\033[32m       Installation Complete!           \033[0m"
    echo -e "\033[32m========================================\033[0m"
    echo ""
    echo -e "\033[36mVerification:\033[0m"

    # Source nvm for verification
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    # Ensure bun is in PATH for verification
    [[ -d "$HOME/.bun/bin" ]] && export PATH="$HOME/.bun/bin:$PATH"

    local tools=("code:VS Code" "git:Git" "node:Node.js" "npm:npm" "bun:Bun" "claude:Claude Code")
    for tool_entry in "${tools[@]}"; do
        local cmd="${tool_entry%%:*}"
        local name="${tool_entry##*:}"
        local version=""

        if command_exists "$cmd"; then
            version=$("$cmd" --version 2>/dev/null | head -1)
            local padding
            padding=$(printf '%*s' $((16 - ${#name})) '')
            echo -e "  \033[32m[OK]\033[0m $name$padding$version"
        else
            local padding
            padding=$(printf '%*s' $((16 - ${#name})) '')
            echo -e "  \033[33m[--]\033[0m $name$padding(not in PATH - restart terminal)"
        fi
    done

    echo ""
    echo "Next steps:"
    echo "  1. Open a NEW terminal window (to load PATH changes)"
    echo "  2. Open VS Code (type 'code' in terminal)"
    echo "  3. Open a terminal in VS Code (Cmd + \`)"
    echo "  4. Type 'claude' to start Claude Code"
    echo "  5. You'll be prompted to authenticate on first run"
    echo ""
    echo -e "\033[33mNote: You may need to open a new terminal for all PATH changes to take effect.\033[0m"
    echo ""
}

main "$@"

#!/bin/bash
# Claude Code macOS Uninstaller
# Removes VS Code, Git, Node.js (nvm), Homebrew, and Claude Code
# NOTE: Xcode CLI Tools are intentionally NOT uninstalled
#
# Usage:
#   bash uninstall.sh                # Standard uninstall
#   bash uninstall.sh --debug        # Enable debug output

set -uo pipefail

DEBUG_MODE=false
STEP_TOTAL=7
CURRENT_STEP=0

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

# ============================================================
# Uninstall Functions
# ============================================================

uninstall_claude_code() {
    print_step "Uninstalling Claude Code..."

    # Source nvm so npm is available
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    if ! command_exists claude; then
        print_skip "Claude Code is not installed"
    else
        npm uninstall -g @anthropic-ai/claude-code 2>/dev/null && \
            print_success "Claude Code uninstalled" || \
            print_error "Failed to uninstall Claude Code"
    fi

    # Clean up Claude Code config
    if [[ -d "$HOME/.claude" ]]; then
        print_debug "Removing ~/.claude"
        rm -rf "$HOME/.claude"
        print_success "Claude Code configuration removed"
    fi
}

uninstall_vscode_extensions() {
    print_step "Removing VS Code extensions..."

    if ! command_exists code; then
        local code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        if [[ ! -x "$code_bin" ]]; then
            print_skip "VS Code not found, skipping extension removal"
            return
        fi
        local code_cmd="$code_bin"
    else
        local code_cmd="code"
    fi

    "$code_cmd" --uninstall-extension anthropics.claude-code --force &>/dev/null && \
        print_success "Claude Code extension removed" || \
        print_debug "Extension removal returned non-zero (may already be removed)"
}

uninstall_vscode() {
    print_step "Uninstalling VS Code..."

    if [[ ! -d "/Applications/Visual Studio Code.app" ]]; then
        print_skip "VS Code is not installed"
        return
    fi

    # If installed via Homebrew
    if command_exists brew && brew list --cask visual-studio-code &>/dev/null; then
        brew uninstall --cask visual-studio-code 2>/dev/null && \
            print_success "VS Code uninstalled via Homebrew" || \
            print_error "Failed to uninstall VS Code via Homebrew"
    else
        # Manual removal
        rm -rf "/Applications/Visual Studio Code.app"
        print_success "VS Code application removed"
    fi

    # Clean up VS Code settings and data
    local vscode_dirs=(
        "$HOME/Library/Application Support/Code"
        "$HOME/.vscode"
    )
    for dir in "${vscode_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_debug "Removing: $dir"
            rm -rf "$dir"
        fi
    done
    print_success "VS Code settings and data cleaned up"

    # Remove PATH entry from .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i '' '/Visual Studio Code/d' "$HOME/.zshrc" 2>/dev/null
        print_debug "Removed VS Code PATH from .zshrc"
    fi
}

uninstall_nodejs_nvm() {
    print_step "Uninstalling Node.js and nvm..."

    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

    if [[ ! -d "$NVM_DIR" ]]; then
        if ! command_exists node; then
            print_skip "nvm and Node.js are not installed"
            return
        fi
    fi

    # Remove nvm directory
    if [[ -d "$NVM_DIR" ]]; then
        print_debug "Removing nvm directory: $NVM_DIR"
        rm -rf "$NVM_DIR"
        print_success "nvm and all Node.js versions removed"
    fi

    # Clean up nvm lines from shell profiles
    local profiles=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile")
    for profile in "${profiles[@]}"; do
        if [[ -f "$profile" ]]; then
            # Remove nvm-related lines
            sed -i '' '/NVM_DIR/d' "$profile" 2>/dev/null
            sed -i '' '/nvm\.sh/d' "$profile" 2>/dev/null
            sed -i '' '/nvm.*bash_completion/d' "$profile" 2>/dev/null
            print_debug "Cleaned nvm entries from $profile"
        fi
    done
    print_success "nvm shell configuration cleaned up"
}

uninstall_git() {
    print_step "Uninstalling Git..."

    # Only uninstall if it was installed via Homebrew (don't remove Xcode git)
    if command_exists brew && brew list git &>/dev/null; then
        brew uninstall git 2>/dev/null && \
            print_success "Git uninstalled (Homebrew version)" || \
            print_error "Failed to uninstall Git"
    else
        print_skip "Git was not installed via Homebrew (keeping system Git)"
    fi

    # Clean up git config
    if [[ -f "$HOME/.gitconfig" ]]; then
        print_debug "Removing ~/.gitconfig"
        rm -f "$HOME/.gitconfig"
        print_success "Git global configuration removed"
    fi
}

uninstall_homebrew() {
    print_step "Uninstalling Homebrew..."

    if ! command_exists brew; then
        print_skip "Homebrew is not installed"
        return
    fi

    echo "  Uninstalling Homebrew (this may take a minute)..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" 2>/dev/null && \
        print_success "Homebrew uninstalled" || \
        print_error "Homebrew uninstall script failed. You may need to remove it manually."

    # Clean up Homebrew PATH from shell profiles
    local profiles=("$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile")
    for profile in "${profiles[@]}"; do
        if [[ -f "$profile" ]]; then
            sed -i '' '/brew shellenv/d' "$profile" 2>/dev/null
            sed -i '' '/homebrew/Id' "$profile" 2>/dev/null
            print_debug "Cleaned Homebrew entries from $profile"
        fi
    done
    print_success "Homebrew shell configuration cleaned up"
}

clean_git_config() {
    print_step "Cleaning up Git configuration..."

    if [[ -f "$HOME/.gitconfig" ]]; then
        rm -f "$HOME/.gitconfig"
        print_success "Git global config (.gitconfig) removed"
    else
        print_skip "No .gitconfig found"
    fi
}

# ============================================================
# Main Uninstall Flow
# ============================================================

main() {
    echo ""
    echo -e "\033[31m========================================\033[0m"
    echo -e "\033[31m   Claude Code One-Click Uninstaller    \033[0m"
    echo -e "\033[31m             for macOS                   \033[0m"
    echo -e "\033[31m========================================\033[0m"
    echo ""
    echo "This will uninstall: VS Code, Git (Homebrew), Node.js (nvm), Homebrew, and Claude Code"
    echo -e "\033[33mWARNING: This will also remove VS Code settings, extensions, and Git config.\033[0m"
    echo -e "\033[90mNote: Xcode Command Line Tools will NOT be removed.\033[0m"
    echo ""

    read -p "Are you sure you want to uninstall everything? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi

    # Uninstall in reverse order (dependencies last)
    uninstall_claude_code        # Step 1 - Remove Claude Code first (depends on npm)
    uninstall_vscode_extensions  # Step 2 - Remove extensions before VS Code
    uninstall_vscode             # Step 3 - Remove VS Code
    uninstall_nodejs_nvm         # Step 4 - Remove Node.js and nvm
    uninstall_git                # Step 5 - Remove Git (Homebrew version only)
    uninstall_homebrew           # Step 6 - Remove Homebrew
    clean_git_config             # Step 7 - Clean up any remaining Git config

    # Summary
    echo ""
    echo -e "\033[32m========================================\033[0m"
    echo -e "\033[32m       Uninstall Complete!              \033[0m"
    echo -e "\033[32m========================================\033[0m"
    echo ""
    echo "All tools have been uninstalled."
    echo -e "\033[90mXcode Command Line Tools were intentionally kept.\033[0m"
    echo ""
    echo -e "\033[33mPlease open a new terminal window for all changes to take effect.\033[0m"
    echo ""
}

main "$@"

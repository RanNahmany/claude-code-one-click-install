#!/bin/bash
# Claude Code One-Click Installer - macOS Launcher
# Automatically detects local vs remote installation mode
#
# Usage:
#   bash install.sh                    (from cloned repo)
#   bash install.sh --debug            (enable debug output)
#   curl -fsSL "...install.sh" | bash  (single command)

set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/RanNahmany/claude-code-one-click-install/main/mac"
DEBUG_MODE=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --debug|-debug) DEBUG_MODE=true ;;
    esac
done

export DEBUG_MODE

echo "========================================"
echo "   Claude Code One-Click Installer"
echo "========================================"
echo ""

# Determine script directory (works for both local and piped execution)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null || echo ".")" && pwd)"

# Check if local files exist
if [[ -f "$SCRIPT_DIR/src/installer.sh" && -f "$SCRIPT_DIR/src/config.json" ]]; then
    echo "Local installation files detected - using cloned repository"
    [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Local mode, script dir: $SCRIPT_DIR"
    bash "$SCRIPT_DIR/src/installer.sh" "$@"
else
    echo "Downloading installer files..."
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    mkdir -p "$TEMP_DIR/src"

    [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Temp dir: $TEMP_DIR"
    [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] Downloading from: $REPO_BASE"

    curl -fsSL "$REPO_BASE/src/config.json" -o "$TEMP_DIR/src/config.json" || {
        echo "ERROR: Failed to download config.json from GitHub"
        echo "Please check your internet connection and try again."
        exit 1
    }

    curl -fsSL "$REPO_BASE/src/installer.sh" -o "$TEMP_DIR/src/installer.sh" || {
        echo "ERROR: Failed to download installer.sh from GitHub"
        exit 1
    }

    echo "Files downloaded successfully!"
    echo ""
    bash "$TEMP_DIR/src/installer.sh" "$@"
fi

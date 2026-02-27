#!/usr/bin/env bash
set -euo pipefail

# Install Homebrew packages and platform-specific extras.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib/platform.sh"
source "$DOTFILES_DIR/scripts/lib/packages.sh"

PLATFORM="$(detect_platform)"

install_packages "$DOTFILES_DIR"

# --- Platform-specific packages (add extras below) ---

case "$PLATFORM" in
    macos)
        # brew install <formula>
        ;;
    linux)
        brew install pass # secrets backend (macOS uses built-in `security`)
        ;;
esac

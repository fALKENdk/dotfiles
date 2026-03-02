#!/usr/bin/env bash
set -euo pipefail

# Zero-to-configured bootstrap for a fresh machine.
#
# On a new Mac with nothing installed, run:
#   bash <(curl -fsSL https://raw.githubusercontent.com/fALKENdk/dotfiles/main/scripts/bootstrap.sh)
#
# Handles: Xcode Command Line Tools -> git clone -> install.sh
# Safe to re-run — every step is idempotent.

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/fALKENdk/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

ensure_xcode_command_line_tools() {
    if xcode-select -p &>/dev/null; then
        echo "Xcode Command Line Tools: already installed."
        return 0
    fi

    echo "Installing Xcode Command Line Tools..."
    xcode-select --install

    echo "Waiting for installation (follow the GUI prompt)..."
    local waited=0
    until xcode-select -p &>/dev/null; do
        sleep 5
        waited=$((waited + 5))
        if [[ "$waited" -ge 900 ]]; then
            echo "Timed out after 15 minutes waiting for Xcode Command Line Tools." >&2
            exit 1
        fi
    done
    echo "Xcode Command Line Tools: installed."
}

clone_dotfiles() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        echo "Dotfiles: already cloned at $DOTFILES_DIR"
        return 0
    fi

    echo "Cloning dotfiles to $DOTFILES_DIR..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
}

if [[ "$(uname -s)" == "Darwin" ]]; then
    ensure_xcode_command_line_tools
fi

clone_dotfiles

echo "Running install..."
"$DOTFILES_DIR/scripts/install.sh" "$@"

echo
echo "Bootstrap complete. Open a new terminal to activate your shell config."

#!/usr/bin/env bash
set -euo pipefail

# Package installation helpers for Homebrew and Cursor.
#
# Remote installer execution can be disabled by setting:
#   DOTFILES_ALLOW_REMOTE_INSTALLERS=0

# Install Homebrew if not already present, then activate its shell environment.
ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

# Symlink the Cursor CLI into ~/.local/bin when the app bundle exists
# but the `cursor` command isn't on PATH yet.
ensure_cursor_cli() {
    local cursor_cli_source=""

    if command -v cursor >/dev/null 2>&1; then
        return 0
    fi

    if [[ -x "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]]; then
        cursor_cli_source="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    elif [[ -x "$HOME/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]]; then
        cursor_cli_source="$HOME/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    elif [[ -x "/opt/Cursor/resources/app/bin/cursor" ]]; then
        cursor_cli_source="/opt/Cursor/resources/app/bin/cursor"
    elif [[ -x "$HOME/.local/share/cursor/resources/app/bin/cursor" ]]; then
        cursor_cli_source="$HOME/.local/share/cursor/resources/app/bin/cursor"
    fi

    if [[ -n "$cursor_cli_source" ]]; then
        mkdir -p "$HOME/.local/bin"
        ln -sfn "$cursor_cli_source" "$HOME/.local/bin/cursor"
        echo "Cursor CLI linked at: $HOME/.local/bin/cursor"
    else
        echo "Cursor app installed, but cursor CLI source was not found."
    fi
}

# Install Cursor via the official installer script, then link the CLI.
install_cursor_official() {
    if command -v cursor >/dev/null 2>&1; then
        echo "Cursor CLI already available."
        return 0
    fi

    if [[ "${DOTFILES_ALLOW_REMOTE_INSTALLERS:-1}" != "1" ]]; then
        echo "Skipping Cursor installer (DOTFILES_ALLOW_REMOTE_INSTALLERS=0)."
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        echo "Installing Cursor via official installer..."
        curl https://cursor.com/install -fsS | bash
    else
        echo "curl not found; skipping Cursor installer."
    fi

    ensure_cursor_cli
}

# Run `brew bundle` on the Brewfile, then install Cursor.
#
# @param $1 dotfiles_dir - path to the dotfiles root (must contain Brewfile)
install_packages() {
    local dotfiles_dir="$1"

    ensure_homebrew

    if [[ ! -f "$dotfiles_dir/Brewfile" ]]; then
        echo "Brewfile not found at $dotfiles_dir/Brewfile" >&2
        exit 1
    fi

    echo "Installing packages from Brewfile..."
    brew bundle --file "$dotfiles_dir/Brewfile"
    install_cursor_official
}

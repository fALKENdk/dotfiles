#!/usr/bin/env bash
set -euo pipefail

# Entry point for machine setup: packages, symlinks, and macOS defaults.
# Uses manual DOTFILES_DIR instead of lib/init.sh because this script
# runs before symlinks exist.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib/platform.sh"
PLATFORM="$(detect_platform)"
SKIP_MACOS=0

for arg in "$@"; do
    case "$arg" in
        --skip-macos) SKIP_MACOS=1 ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Usage: ./scripts/install.sh [--skip-macos]" >&2
            exit 1
            ;;
    esac
done

echo "==> Installing packages"
"$DOTFILES_DIR/scripts/packages.sh"
activate_homebrew

echo "==> Ensuring Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    if [[ "${DOTFILES_ALLOW_REMOTE_INSTALLERS:-1}" == "1" ]]; then
        KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        echo "Skipping Oh My Zsh install (DOTFILES_ALLOW_REMOTE_INSTALLERS=0)."
    fi
else
    echo "Oh My Zsh already installed."
fi

echo "==> Seeding local config"
"$DOTFILES_DIR/scripts/local.sh" init

echo "==> Creating symlinks"
"$DOTFILES_DIR/scripts/symlinks.sh"

if [[ "$PLATFORM" == "macos" ]] && [[ "$SKIP_MACOS" -eq 0 ]]; then
    echo "==> Applying macOS defaults"
    "$DOTFILES_DIR/scripts/macos.sh"
fi

echo "==> Done"
echo "Run '$DOTFILES_DIR/scripts/audit.sh' to verify security and setup."

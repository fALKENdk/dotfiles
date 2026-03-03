#!/usr/bin/env bash
set -euo pipefail

# Uses manual DOTFILES_DIR instead of lib/init.sh because this script
# runs before symlinks exist.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib/platform.sh"
PLATFORM="$(detect_platform)"
SKIP_MACOS=0
RESTORE_PATH=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --skip-macos)
            SKIP_MACOS=1
            shift
            ;;
        --restore)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --restore requires a path argument." >&2
                exit 1
            fi
            RESTORE_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: ./scripts/install.sh [--skip-macos] [--restore <path>]" >&2
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

if [[ -n "$RESTORE_PATH" ]]; then
    echo "==> Restoring from backup"
    "$DOTFILES_DIR/scripts/restore.sh" "$RESTORE_PATH"
fi

echo "==> Seeding local config"
"$DOTFILES_DIR/scripts/local.sh" init

echo "==> Creating symlinks and generating configs"
"$DOTFILES_DIR/scripts/symlinks.sh"

if [[ "$PLATFORM" == "macos" ]] && [[ "$SKIP_MACOS" -eq 0 ]]; then
    echo "==> Applying macOS defaults"
    "$DOTFILES_DIR/scripts/macos.sh"
fi

echo "==> Done"
echo "Run '$DOTFILES_DIR/scripts/audit.sh' to verify security and setup."

#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib/platform.sh"
source "$DOTFILES_DIR/scripts/lib/packages.sh"

PLATFORM="$(detect_platform)"

install_packages "$DOTFILES_DIR"

if [[ "$PLATFORM" == "linux" ]] && ! command -v pass >/dev/null 2>&1; then
    brew install pass
fi

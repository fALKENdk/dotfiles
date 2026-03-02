#!/usr/bin/env bash
# Shared bootstrap for CLI scripts invoked via symlink.

_resolve_script_dir() {
    local path="$1"
    while [[ -L "$path" ]]; do
        local target
        target="$(readlink "$path")"
        if [[ "$target" == /* ]]; then
            path="$target"
        else
            path="$(cd "$(dirname "$path")/$(dirname "$target")" && pwd)/$(basename "$target")"
        fi
    done
    cd "$(dirname "$path")" && pwd
}

DOTFILES_DIR="$(cd "$(_resolve_script_dir "${BASH_SOURCE[1]}")/.." && pwd)"
DOTFILES_TIMESTAMP="${DOTFILES_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
unset -f _resolve_script_dir

source "$DOTFILES_DIR/scripts/lib/platform.sh"

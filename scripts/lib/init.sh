#!/usr/bin/env bash
# Shared bootstrap for CLI scripts invoked via symlink.
# Resolves the caller's symlink chain, then exports SCRIPT_DIR and DOTFILES_DIR.
#
# @global SCRIPT_DIR   - absolute path to the calling script's directory
# @global DOTFILES_DIR - absolute path to the dotfiles root
# @uses lib/platform.sh

# Walk the symlink chain to find the real script directory.
#
# @param $1 path - path that may be a symlink
# @return stdout - absolute directory containing the resolved script
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

SCRIPT_DIR="$(_resolve_script_dir "${BASH_SOURCE[1]}")"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
unset -f _resolve_script_dir

source "$DOTFILES_DIR/scripts/lib/platform.sh"

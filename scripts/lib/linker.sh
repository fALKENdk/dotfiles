#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backups/${DOTFILES_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}}"

# Managed symlinks (pointing into $DOTFILES_DIR) are removed silently.
# Real files are moved to $BACKUP_DIR.
backup_if_needed() {
    local target="$1"
    local link_target

    if [[ -L "$target" ]]; then
        link_target="$(readlink "$target" 2>/dev/null || true)"
        if [[ "$link_target" == "${DOTFILES_DIR:-$HOME/.dotfiles}/"* ]]; then
            rm "$target"
            echo "Removed managed symlink: $target"
        fi
        return 0
    fi

    if [[ -e "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        local safe_name="${target#/}"
        safe_name="${safe_name//\//__}"
        mv "$target" "$BACKUP_DIR/$safe_name"
        echo "Backed up: $target -> $BACKUP_DIR/$safe_name"
    fi
}

link_file() {
    local source_path="$1"
    local target_path="$2"

    if [[ ! -e "$source_path" ]]; then
        echo "Source not found: $source_path" >&2
        return 1
    fi

    backup_if_needed "$target_path"
    mkdir -p "$(dirname "$target_path")"
    ln -sfn "$source_path" "$target_path"
    echo "Linked: $target_path -> $source_path"
}

link_command() {
    local source_path="$1"
    local command_name="$2"
    local target_path="$HOME/.local/bin/$command_name"

    if [[ ! -e "$source_path" ]]; then
        echo "Source not found: $source_path" >&2
        return 1
    fi

    mkdir -p "$HOME/.local/bin"
    backup_if_needed "$target_path"
    ln -sfn "$source_path" "$target_path"
    echo "Linked: $command_name -> $source_path"
}

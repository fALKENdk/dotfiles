#!/usr/bin/env bash
set -euo pipefail

# Uses manual DOTFILES_DIR instead of lib/init.sh because this script
# creates the symlinks and generated configs that lib/init.sh relies on.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib/platform.sh"
source "$DOTFILES_DIR/scripts/lib/linker.sh"
PLATFORM="$(detect_platform)"

link_file "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

# Git config is generated from local/ sources with auto-detected identity includes.
if [[ -f "$DOTFILES_DIR/local/git/.gitconfig" ]]; then
    backup_if_needed "$HOME/.gitconfig"
    cp "$DOTFILES_DIR/local/git/.gitconfig" "$HOME/.gitconfig"

    for file in "$DOTFILES_DIR/local/git"/.gitconfig-*; do
        [[ -f "$file" ]] || continue
        provider_name="${file##*/.gitconfig-}"
        link_file "$file" "$HOME/.gitconfig-$provider_name"

        case "$provider_name" in
        github)
            printf '\n[includeIf "hasconfig:remote.*.url:git@github.com:*/**"]\n    path = ~/.gitconfig-%s\n' "$provider_name" >>"$HOME/.gitconfig"
            printf '\n[includeIf "hasconfig:remote.*.url:https://github.com/*/**"]\n    path = ~/.gitconfig-%s\n' "$provider_name" >>"$HOME/.gitconfig"
            ;;
        azure-devops)
            printf '\n[includeIf "hasconfig:remote.*.url:git@ssh.dev.azure.com:*/**"]\n    path = ~/.gitconfig-%s\n' "$provider_name" >>"$HOME/.gitconfig"
            printf '\n[includeIf "hasconfig:remote.*.url:https://dev.azure.com/*/**"]\n    path = ~/.gitconfig-%s\n' "$provider_name" >>"$HOME/.gitconfig"
            ;;
        *)
            printf '\n[include]\n    path = ~/.gitconfig-%s\n' "$provider_name" >>"$HOME/.gitconfig"
            ;;
        esac
    done
    echo "Generated: ~/.gitconfig"
else
    echo "Skipped: ~/.gitconfig (run 'dotfiles-local init' first)"
fi

# npm config is generated from local/ sources with optional registry additions.
if [[ -f "$DOTFILES_DIR/local/npm/.npmrc" ]]; then
    backup_if_needed "$HOME/.npmrc"
    cp "$DOTFILES_DIR/local/npm/.npmrc" "$HOME/.npmrc"

    has_npm_extras=0
    for file in "$DOTFILES_DIR/local/npm"/.npmrc-*; do
        [[ -f "$file" ]] || continue
        cat "$file" >>"$HOME/.npmrc"
        has_npm_extras=1
    done

    if [[ "$has_npm_extras" -eq 1 ]]; then
        echo "Generated: ~/.npmrc (settings + local additions)"
    else
        echo "Generated: ~/.npmrc (settings only)"
    fi
else
    echo "Skipped: ~/.npmrc (run 'dotfiles-local init' first)"
fi

mkdir -p "$HOME/.ssh"
link_file "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
chmod 700 "$HOME/.ssh"
chmod 600 "$HOME/.ssh/config" || true

link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"

mkdir -p "$HOME/.config/dotfiles"
printf '%s\n' "$PLATFORM" >"$HOME/.config/dotfiles/platform"
echo "Platform set: $HOME/.config/dotfiles/platform -> $PLATFORM"

case "$PLATFORM" in
macos)
    link_file \
        "$DOTFILES_DIR/config/cursor/settings.json" \
        "$HOME/Library/Application Support/Cursor/User/settings.json"
    ;;
linux)
    link_file \
        "$DOTFILES_DIR/config/cursor/settings.json" \
        "$HOME/.config/Cursor/User/settings.json"
    ;;
esac

link_command "$DOTFILES_DIR/scripts/dotfiles.sh" "dotfiles"
link_command "$DOTFILES_DIR/scripts/backup.sh" "dotfiles-backup"
link_command "$DOTFILES_DIR/scripts/secrets.sh" "dotfiles-secrets"
link_command "$DOTFILES_DIR/scripts/ssh.sh" "dotfiles-ssh"
link_command "$DOTFILES_DIR/scripts/local.sh" "dotfiles-local"

echo "Symlinks and generated configs complete."

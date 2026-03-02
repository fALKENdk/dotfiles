#!/usr/bin/env bash
set -euo pipefail

# Uses manual DOTFILES_DIR instead of lib/init.sh because this script
# creates the symlinks that lib/init.sh relies on.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib/platform.sh"
source "$DOTFILES_DIR/scripts/lib/linker.sh"
PLATFORM="$(detect_platform)"

link_file "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

for file in "$DOTFILES_DIR/local/git"/.gitconfig-*; do
    [[ -f "$file" ]] || continue
    link_file "$file" "$HOME/$(basename "$file")"
done

# npm config is concatenated, not symlinked.
backup_if_needed "$HOME/.npmrc"
cp "$DOTFILES_DIR/npm/.npmrc" "$HOME/.npmrc"
if [[ -f "$DOTFILES_DIR/local/npm/.npmrc-registries" ]]; then
    cat "$DOTFILES_DIR/local/npm/.npmrc-registries" >>"$HOME/.npmrc"
    echo "Generated: ~/.npmrc (settings + local registries)"
else
    echo "Generated: ~/.npmrc (settings only, no local registries)"
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

echo "Symlink setup complete."

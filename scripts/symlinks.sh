#!/usr/bin/env bash
set -euo pipefail

# Link managed dotfiles and helper commands.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib/platform.sh"
source "$DOTFILES_DIR/scripts/lib/linker.sh"
PLATFORM="$(detect_platform)"

# --- Git ---
link_file "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

for f in "$DOTFILES_DIR/local/git"/.gitconfig-*; do
    [[ -f "$f" ]] || continue
    link_file "$f" "$HOME/$(basename "$f")"
done

# --- npm (concatenated, not symlinked) ---
backup_if_needed "$HOME/.npmrc"
cp "$DOTFILES_DIR/npm/.npmrc" "$HOME/.npmrc"
if [[ -f "$DOTFILES_DIR/local/npm/.npmrc-registries" ]]; then
    cat "$DOTFILES_DIR/local/npm/.npmrc-registries" >>"$HOME/.npmrc"
    echo "Generated: ~/.npmrc (settings + local registries)"
else
    echo "Generated: ~/.npmrc (settings only, no local registries)"
fi

# --- SSH ---
mkdir -p "$HOME/.ssh"
link_file "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
chmod 700 "$HOME/.ssh"
chmod 600 "$HOME/.ssh/config" || true

# --- Shell ---
link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"

mkdir -p "$HOME/.config/dotfiles"
printf '%s\n' "$PLATFORM" >"$HOME/.config/dotfiles/platform"
echo "Platform set: $HOME/.config/dotfiles/platform -> $PLATFORM"

# --- Apps ---
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

# --- CLI tools ---
link_command "$DOTFILES_DIR/scripts/dotfiles.sh" "dotfiles"
link_command "$DOTFILES_DIR/scripts/backup.sh" "dotfiles-backup"
link_command "$DOTFILES_DIR/scripts/keychain-secrets.sh" "keychain-secrets"
link_command "$DOTFILES_DIR/scripts/ssh-keys-backup.sh" "ssh-keys-backup"
link_command "$DOTFILES_DIR/scripts/local-config.sh" "local-config"

echo "Symlink setup complete."

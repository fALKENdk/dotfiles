#!/usr/bin/env bash
set -euo pipefail

# Unified entry point for all dotfiles commands.
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"

usage() {
    cat <<EOF
Usage: dotfiles <command> [args...]

  install     Full machine setup (packages, symlinks, defaults)
  packages    Install Homebrew packages from Brewfile
  symlinks    Create/update dotfile symlinks
  macos       Apply macOS system defaults
  secrets     Manage keychain/pass secrets
  local       Manage machine-specific local/ config
  ssh         Manage SSH key backups
  backup      Run all backups (local config, secrets, SSH keys)
  audit       Health check (timing, permissions, secrets, lint)

Run 'dotfiles <command> help' for subcommand details.
EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
    _completions) echo "install packages symlinks macos secrets local ssh backup audit help" ;;
    install) exec "$DOTFILES_DIR/scripts/install.sh" "$@" ;;
    packages) exec "$DOTFILES_DIR/scripts/packages.sh" "$@" ;;
    symlinks) exec "$DOTFILES_DIR/scripts/symlinks.sh" "$@" ;;
    macos) exec "$DOTFILES_DIR/scripts/macos.sh" "$@" ;;
    audit) exec "$DOTFILES_DIR/scripts/audit.sh" "$@" ;;
    secrets) exec "$DOTFILES_DIR/scripts/keychain-secrets.sh" "$@" ;;
    ssh) exec "$DOTFILES_DIR/scripts/ssh-keys-backup.sh" "$@" ;;
    local) exec "$DOTFILES_DIR/scripts/local-config.sh" "$@" ;;
    backup) exec "$DOTFILES_DIR/scripts/backup.sh" "$@" ;;
    help | -h | --help) usage ;;
    *)
        echo "Unknown command: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac

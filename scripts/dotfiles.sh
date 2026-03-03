#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2> /dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"

usage() {
    cat << EOF
Usage: dotfiles <command> [args...]

  install     Full machine setup (packages, local config, symlinks, defaults)
  packages    Install Homebrew packages from Brewfile
  symlinks    Create symlinks and generate ~/.gitconfig, ~/.npmrc from local/
  macos       Apply macOS system defaults
  secrets     Manage secrets
  local       Manage machine-specific local/ config
  ssh         Manage SSH key backups
  backup      Run all backups (local config, secrets, SSH keys)
  restore     Restore from encrypted backups
  audit       Health check (timing, permissions, secrets, lint)

Run 'dotfiles <command> help' for subcommand details.
EOF
}

subcommand="${1:-help}"
shift || true

case "$subcommand" in
    _completions) echo "install packages symlinks macos secrets local ssh backup restore audit help" ;;
    install) exec "$DOTFILES_DIR/scripts/install.sh" "$@" ;;
    packages) exec "$DOTFILES_DIR/scripts/packages.sh" "$@" ;;
    symlinks) exec "$DOTFILES_DIR/scripts/symlinks.sh" "$@" ;;
    macos) exec "$DOTFILES_DIR/scripts/macos.sh" "$@" ;;
    audit) exec "$DOTFILES_DIR/scripts/audit.sh" "$@" ;;
    secrets) exec "$DOTFILES_DIR/scripts/secrets.sh" "$@" ;;
    ssh) exec "$DOTFILES_DIR/scripts/ssh.sh" "$@" ;;
    local) exec "$DOTFILES_DIR/scripts/local.sh" "$@" ;;
    backup) exec "$DOTFILES_DIR/scripts/backup.sh" "$@" ;;
    restore) exec "$DOTFILES_DIR/scripts/restore.sh" "$@" ;;
    help | -h | --help) usage ;;
    *)
        echo "Unknown command: $subcommand" >&2
        usage >&2
        exit 1
        ;;
esac

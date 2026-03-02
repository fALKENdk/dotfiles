#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"

usage() {
    cat <<EOF
Usage:
  dotfiles backup [output_directory]
  dotfiles-backup [output_directory]

Examples:
  dotfiles backup
  dotfiles backup ~/backups/dotfiles
  DOTFILES_BACKUP_PASSPHRASE='...' dotfiles backup ~/backups/dotfiles

Notes:
  - Defaults to $DOTFILES_DIR/backups/<timestamp>/
  - Override base directory with DOTFILES_BACKUP_DIR or a positional argument
  - Each run creates a timestamped subdirectory with local.enc, secrets.enc, ssh.enc
  - Set DOTFILES_BACKUP_PASSPHRASE for non-interactive backup
EOF
}

main() {
    case "${1:-}" in
    -h | --help | help)
        usage
        return 0
        ;;
    esac

    if [[ "$#" -gt 1 ]]; then
        usage >&2
        exit 1
    fi

    local base_directory="${1:-${DOTFILES_BACKUP_DIR:-$DOTFILES_DIR/backups}}"
    local backup_directory="$base_directory/$DOTFILES_TIMESTAMP"
    local local_backup secrets_backup ssh_backup

    ensure_passphrase

    mkdir -p "$backup_directory"
    backup_directory="$(cd "$backup_directory" && pwd)"

    local_backup="$backup_directory/local.enc"
    secrets_backup="$backup_directory/secrets.enc"
    ssh_backup="$backup_directory/ssh.enc"

    echo "Writing backups to: $backup_directory"
    "$DOTFILES_DIR/scripts/local.sh" backup "$local_backup"
    "$DOTFILES_DIR/scripts/secrets.sh" backup "$secrets_backup"
    "$DOTFILES_DIR/scripts/ssh.sh" backup "$ssh_backup"

    echo "All backups complete:"
    echo "  - $local_backup"
    echo "  - $secrets_backup"
    echo "  - $ssh_backup"
}

main "$@"

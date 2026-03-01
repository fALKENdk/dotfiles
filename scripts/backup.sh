#!/usr/bin/env bash
set -euo pipefail

# Run all encrypted backup tasks in one command.
# Creates local, secrets, and SSH key backups in one folder.
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"

usage() {
    cat <<'EOF'
Usage:
  dotfiles backup [output_dir]
  dotfiles-backup [output_dir]

Examples:
  dotfiles backup
  dotfiles backup ~/backups/dotfiles
  DOTFILES_BACKUP_DIR=~/backups/dotfiles dotfiles backup

Notes:
  - output_dir defaults to DOTFILES_BACKUP_DIR, then to $HOME
  - file names include a shared timestamp so all artifacts match
  - set DOTFILES_BACKUP_PASSPHRASE for non-interactive backup
EOF
}

main() {
    local output_dir="${1:-${DOTFILES_BACKUP_DIR:-$HOME}}"
    local timestamp="$DOTFILES_TIMESTAMP"
    local local_backup
    local secrets_backup
    local ssh_backup

    if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        return 0
    fi

    if [[ "$#" -gt 1 ]]; then
        usage
        exit 1
    fi

    if [[ -z "${DOTFILES_BACKUP_PASSPHRASE:-}" ]]; then
        read -rsp "Enter backup passphrase: " DOTFILES_BACKUP_PASSPHRASE
        echo
        export DOTFILES_BACKUP_PASSPHRASE
    fi

    mkdir -p "$output_dir"
    output_dir="$(cd "$output_dir" && pwd)"

    local_backup="$output_dir/local-$timestamp.enc"
    secrets_backup="$output_dir/secrets-$timestamp.enc"
    ssh_backup="$output_dir/ssh-$timestamp.enc"

    echo "Writing backups to: $output_dir"
    "$DOTFILES_DIR/scripts/local.sh" backup "$local_backup"
    "$DOTFILES_DIR/scripts/secrets.sh" backup "$secrets_backup"
    "$DOTFILES_DIR/scripts/ssh.sh" backup "$ssh_backup"

    echo "All backups complete:"
    echo "  - $local_backup"
    echo "  - $secrets_backup"
    echo "  - $ssh_backup"
}

main "$@"

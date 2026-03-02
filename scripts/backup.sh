#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"

usage() {
    cat <<'EOF'
Usage:
  dotfiles backup [output_dir]
  dotfiles-backup [output_dir]

Examples:
  dotfiles backup
  dotfiles backup ~/backups/dotfiles
  DOTFILES_BACKUP_PASSPHRASE='...' dotfiles backup ~/backups/dotfiles

Notes:
  - output_dir defaults to DOTFILES_BACKUP_DIR, then to $HOME
  - File names include a shared timestamp so all artifacts match
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

    local output_dir="${1:-${DOTFILES_BACKUP_DIR:-$HOME}}"
    local local_backup secrets_backup ssh_backup

    ensure_passphrase

    mkdir -p "$output_dir"
    output_dir="$(cd "$output_dir" && pwd)"

    local_backup="$output_dir/local-$DOTFILES_TIMESTAMP.enc"
    secrets_backup="$output_dir/secrets-$DOTFILES_TIMESTAMP.enc"
    ssh_backup="$output_dir/ssh-$DOTFILES_TIMESTAMP.enc"

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

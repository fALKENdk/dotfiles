#!/usr/bin/env bash
set -euo pipefail

# Restore all encrypted backups in one command.
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"

usage() {
    cat <<'EOF'
Usage:
  dotfiles restore <backup_dir>
  dotfiles restore --local <file.enc> --secrets <file.enc> --ssh <file.enc>

Examples:
  dotfiles restore ~/backups/dotfiles
  dotfiles restore --local ~/local.enc --ssh ~/ssh.enc
  DOTFILES_BACKUP_PASSPHRASE='...' dotfiles restore ~/backups/dotfiles

Notes:
  - When given a directory, auto-detects files matching local-*.enc, secrets-*.enc, ssh-*.enc
  - Only the most recent file per type is used when multiple matches exist
  - Set DOTFILES_BACKUP_PASSPHRASE for non-interactive restore
  - Overwrite existing files with DOTFILES_LOCAL_RESTORE_OVERWRITE=1 / DOTFILES_SSH_RESTORE_OVERWRITE=1
EOF
}

find_latest() {
    local dir="$1" pattern="$2"
    find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null | sort -r | head -1
}

main() {
    local local_backup="" secrets_backup="" ssh_backup=""

    if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
        usage
        return 0
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --local)
                local_backup="${2:-}"
                shift 2
                ;;
            --secrets)
                secrets_backup="${2:-}"
                shift 2
                ;;
            --ssh)
                ssh_backup="${2:-}"
                shift 2
                ;;
            *)
                if [[ -d "$1" ]]; then
                    local dir
                    dir="$(cd "$1" && pwd)"
                    local_backup="$(find_latest "$dir" "local-*.enc")"
                    secrets_backup="$(find_latest "$dir" "secrets-*.enc")"
                    ssh_backup="$(find_latest "$dir" "ssh-*.enc")"
                    shift
                else
                    echo "Unknown argument or directory not found: $1" >&2
                    usage >&2
                    exit 1
                fi
                ;;
        esac
    done

    if [[ -z "$local_backup" && -z "$secrets_backup" && -z "$ssh_backup" ]]; then
        echo "No backup files found or specified." >&2
        exit 1
    fi

    if [[ -z "${DOTFILES_BACKUP_PASSPHRASE:-}" ]]; then
        read -rsp "Enter backup passphrase: " DOTFILES_BACKUP_PASSPHRASE
        echo
        export DOTFILES_BACKUP_PASSPHRASE
    fi

    if [[ -n "$local_backup" ]]; then
        echo "Restoring local config from: $local_backup"
        "$DOTFILES_DIR/scripts/local.sh" restore "$local_backup"
    fi

    if [[ -n "$secrets_backup" ]]; then
        echo "Restoring secrets from: $secrets_backup"
        "$DOTFILES_DIR/scripts/secrets.sh" restore "$secrets_backup"
    fi

    if [[ -n "$ssh_backup" ]]; then
        echo "Restoring SSH keys from: $ssh_backup"
        "$DOTFILES_DIR/scripts/ssh.sh" restore "$ssh_backup"
    fi

    echo "Restore complete."
}

main "$@"

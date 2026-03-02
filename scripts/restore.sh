#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"

usage() {
    cat <<EOF
Usage:
  dotfiles restore [backup_directory]
  dotfiles restore <file.enc>
  dotfiles restore --local <file.enc> --secrets <file.enc> --ssh <file.enc>

Examples:
  dotfiles restore
  dotfiles restore backups/20260302-120000
  dotfiles restore backups/20260302-120000/local.enc
  dotfiles restore --local ~/custom-name.enc
  DOTFILES_BACKUP_PASSPHRASE='...' dotfiles restore

Notes:
  - With no arguments, restores from the latest timestamped directory in $DOTFILES_DIR/backups/
  - When given a directory, restores only the .enc files found inside it
  - When given a file, the type is inferred from the filename (local.enc, secrets.enc, ssh.enc)
  - Use --local/--secrets/--ssh flags for files with non-standard names
  - Set DOTFILES_BACKUP_PASSPHRASE for non-interactive restore
  - To overwrite existing files, use --overwrite on the module directly:
    dotfiles-local restore --overwrite <file.enc>
    dotfiles-ssh restore --overwrite <file.enc>
EOF
}

find_latest_subdirectory() {
    local directory="$1"
    find "$directory" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -r | head -1
}

collect_backups_from_directory() {
    local directory="$1"
    [[ -f "$directory/local.enc" ]] && local_backup="$directory/local.enc"
    [[ -f "$directory/secrets.enc" ]] && secrets_backup="$directory/secrets.enc"
    [[ -f "$directory/ssh.enc" ]] && ssh_backup="$directory/ssh.enc"
}

main() {
    local local_backup="" secrets_backup="" ssh_backup=""

    case "${1:-}" in
    -h | --help | help)
        usage
        return 0
        ;;
    esac

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --local | --secrets | --ssh)
            if [[ -z "${2:-}" || "$2" == --* ]]; then
                echo "Error: $1 requires a file path argument." >&2
                exit 1
            fi
            case "$1" in
            --local) local_backup="$2" ;;
            --secrets) secrets_backup="$2" ;;
            --ssh) ssh_backup="$2" ;;
            esac
            shift 2
            ;;
        *)
            if [[ -d "$1" ]]; then
                local directory
                directory="$(cd "$1" && pwd)"
                collect_backups_from_directory "$directory"
            elif [[ -f "$1" ]]; then
                local filename
                filename="$(basename "$1")"
                case "$filename" in
                local.enc | local-*.enc) local_backup="$1" ;;
                secrets.enc | secrets-*.enc) secrets_backup="$1" ;;
                ssh.enc | ssh-*.enc) ssh_backup="$1" ;;
                *)
                    echo "Cannot determine backup type from filename: $filename" >&2
                    echo "Use --local, --secrets, or --ssh to specify the type." >&2
                    exit 1
                    ;;
                esac
            else
                echo "File or directory not found: $1" >&2
                usage >&2
                exit 1
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$local_backup" && -z "$secrets_backup" && -z "$ssh_backup" ]]; then
        local default_backups="$DOTFILES_DIR/backups"
        if [[ -d "$default_backups" ]]; then
            local latest_subdirectory
            latest_subdirectory="$(find_latest_subdirectory "$default_backups")"
            if [[ -n "$latest_subdirectory" ]]; then
                echo "Using latest backup: $latest_subdirectory"
                collect_backups_from_directory "$latest_subdirectory"
            fi
        fi
    fi

    if [[ -z "$local_backup" && -z "$secrets_backup" && -z "$ssh_backup" ]]; then
        echo "No backup files found." >&2
        echo "Run 'dotfiles backup' first, or supply a directory: dotfiles restore <backup_directory>" >&2
        exit 1
    fi

    ensure_passphrase

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

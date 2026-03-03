#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2> /dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"
source "$DOTFILES_DIR/scripts/lib/restore.sh"

usage() {
    cat << EOF
Usage:
  dotfiles-ssh list [ssh_directory]
  dotfiles-ssh backup [output.enc] [ssh_directory]
  dotfiles-ssh restore [--overwrite] <input.enc> [ssh_directory]

Examples:
  dotfiles-ssh list
  dotfiles-ssh backup
  dotfiles-ssh backup ~/ssh-keys.enc
  dotfiles-ssh restore backups/20260302-120000/ssh.enc
  dotfiles-ssh restore --overwrite backups/20260302-120000/ssh.enc

Notes:
  - Source/target ssh_directory defaults to ~/.ssh
  - Backup defaults to $DOTFILES_DIR/backups/<timestamp>/ssh.enc
  - Backup includes: id_* keys (private/public), known_hosts*, authorized_keys
  - Backup file is encrypted with AES-256-CBC + PBKDF2
EOF
}

collect_files() {
    local ssh_directory="$1"
    local pattern file
    local had_nullglob=0

    [[ -d "$ssh_directory" ]] || return 0

    shopt -q nullglob && had_nullglob=1
    shopt -s nullglob

    for pattern in 'id_*' 'known_hosts' 'known_hosts.old' 'authorized_keys'; do
        for file in "$ssh_directory"/$pattern; do
            [[ -f "$file" ]] || continue
            basename "$file"
        done
    done | sort -u

    if [[ "$had_nullglob" -eq 0 ]]; then
        shopt -u nullglob
    fi
}

set_file_permissions() {
    local path="$1"
    local name
    name="$(basename "$path")"

    if [[ "$name" == *.pub || "$name" == known_hosts* ]]; then
        chmod 644 "$path"
    elif [[ "$name" == "authorized_keys" ]]; then
        chmod 600 "$path"
    elif [[ "$name" == id_* ]]; then
        chmod 600 "$path"
    fi
}

command_list() {
    local ssh_directory="${1:-$HOME/.ssh}"
    local files=()
    local file
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(collect_files "$ssh_directory")

    echo "ssh_directory: $ssh_directory"
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "No backup candidate files found."
        return 0
    fi

    for file in "${files[@]}"; do
        ls -l "$ssh_directory/$file"
    done
}

command_backup() {
    local default_directory="$DOTFILES_DIR/backups/$DOTFILES_TIMESTAMP"
    local output="${1:-$default_directory/ssh.enc}"
    local ssh_directory="${2:-$HOME/.ssh}"
    local files=()
    local temp_directory staging_directory archive_file manifest_file
    local file

    require_command tar
    ensure_passphrase_with_confirmation
    mkdir -p "$(dirname "$output")"

    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(collect_files "$ssh_directory")
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "No backup candidate files found in $ssh_directory" >&2
        exit 1
    fi

    temp_directory="$(mktemp -d)"
    trap 'rm -rf "$temp_directory"' EXIT
    staging_directory="$temp_directory/ssh"
    archive_file="$temp_directory/ssh-keys.tar"
    manifest_file="$staging_directory/MANIFEST.txt"
    mkdir -p "$staging_directory"

    for file in "${files[@]}"; do
        cp -p "$ssh_directory/$file" "$staging_directory/$file"
    done

    {
        echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "source_ssh_directory=$ssh_directory"
        echo "files:"
        for file in "${files[@]}"; do
            echo "  - $file"
        done
    } > "$manifest_file"

    tar -cf "$archive_file" -C "$temp_directory" ssh

    encrypt_file "$archive_file" "$output" DOTFILES_BACKUP_PASSPHRASE

    chmod 600 "$output"
    rm -rf "$temp_directory"
    trap - EXIT

    echo "Backup written: $output"
    echo "Files included: ${#files[@]}"
}

command_restore() {
    local input=""
    local ssh_directory="$HOME/.ssh"
    local temp_directory archive_file extract_directory
    local overwrite=0
    local file
    local entries=()
    local positional_arguments=()

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --overwrite)
                overwrite=1
                shift
                ;;
            -*)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            *)
                positional_arguments+=("$1")
                shift
                ;;
        esac
    done

    input="${positional_arguments[0]:-}"
    ssh_directory="${positional_arguments[1]:-$HOME/.ssh}"

    require_command tar

    [[ -n "$input" ]] || {
        usage
        exit 1
    }
    [[ -f "$input" ]] || {
        echo "Backup not found: $input" >&2
        exit 1
    }

    ensure_passphrase
    temp_directory="$(mktemp -d)"
    trap 'rm -rf "$temp_directory"' EXIT
    archive_file="$temp_directory/ssh-keys.tar"
    extract_directory="$temp_directory/extract"

    decrypt_file "$input" "$archive_file" DOTFILES_BACKUP_PASSPHRASE

    while IFS= read -r file; do
        entries+=("$file")
    done < <(tar -tf "$archive_file")

    if [[ "${#entries[@]}" -eq 0 ]]; then
        echo "Backup archive is empty." >&2
        rm -rf "$temp_directory"
        exit 1
    fi

    for file in "${entries[@]}"; do
        [[ "$file" == ssh/* ]] || {
            echo "Unexpected path in archive: $file" >&2
            rm -rf "$temp_directory"
            exit 1
        }
    done

    mkdir -p "$extract_directory"
    tar -xf "$archive_file" -C "$extract_directory"
    mkdir -p "$ssh_directory"
    chmod 700 "$ssh_directory"

    local restore_files=()
    for file in "$extract_directory/ssh"/*; do
        [[ -f "$file" ]] || continue
        local filename
        filename="$(basename "$file")"
        [[ "$filename" == "MANIFEST.txt" ]] && continue
        restore_files+=("$filename")
    done

    if ! check_restore_conflicts "$overwrite" "$ssh_directory" "${restore_files[@]}"; then
        rm -rf "$temp_directory"
        exit 1
    fi

    for file in "${restore_files[@]}"; do
        cp -p "$extract_directory/ssh/$file" "$ssh_directory/$file"
        set_file_permissions "$ssh_directory/$file"
    done

    rm -rf "$temp_directory"
    trap - EXIT
    echo "Restore complete to: $ssh_directory"
}

main() {
    local subcommand="${1:-}"
    shift || true

    [[ "$subcommand" == "_completions" ]] && {
        echo "list backup restore help"
        return
    }

    case "$subcommand" in
        list) command_list "$@" ;;
        backup) command_backup "$@" ;;
        restore) command_restore "$@" ;;
        "" | -h | --help | help) usage ;;
        *)
            echo "Unknown command: $subcommand" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"

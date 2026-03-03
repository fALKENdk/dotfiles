#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2> /dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"
source "$DOTFILES_DIR/scripts/lib/restore.sh"

LOCAL_DIR="$DOTFILES_DIR/local"
EXAMPLE_DIR="$DOTFILES_DIR/local.example"

SEED_FILES=(
    "git/.gitconfig"
    "npm/.npmrc"
    "secrets/secrets-map.json"
)

list_relative_files() {
    local base_directory="$1"
    if command -v fd > /dev/null 2>&1; then
        fd -t f -HI --base-directory "$base_directory"
    else
        (   
            cd "$base_directory"
            find . -type f -print | sed 's|^\./||'
        )
    fi
}

usage() {
    cat << EOF
Usage:
  dotfiles-local init
  dotfiles-local list
  dotfiles-local backup [output.enc]
  dotfiles-local restore [--overwrite] <input.enc>

Examples:
  dotfiles-local init
  dotfiles-local backup
  dotfiles-local backup ~/local.enc
  dotfiles-local restore backups/20260302-120000/local.enc
  dotfiles-local restore --overwrite backups/20260302-120000/local.enc

Notes:
  - init seeds only structural defaults (git config, npm config, secrets map)
  - local.example/ contains additional examples for opt-in use
  - Backup defaults to $DOTFILES_DIR/backups/<timestamp>/local.enc
  - Backup file is encrypted with AES-256-CBC + PBKDF2
EOF
}

command_init() {
    local seeded=0
    local skipped=0

    if [[ ! -d "$EXAMPLE_DIR" ]]; then
        echo "Example directory not found: $EXAMPLE_DIR" >&2
        exit 1
    fi

    for relative_path in "${SEED_FILES[@]}"; do
        local source_path="$EXAMPLE_DIR/$relative_path"
        local destination_path="$LOCAL_DIR/$relative_path"

        if [[ ! -f "$source_path" ]]; then
            echo "  missing example: $relative_path" >&2
            continue
        fi

        if [[ -e "$destination_path" ]]; then
            echo "  exists: $relative_path"
            skipped=$((skipped + 1))
        else
            mkdir -p "$(dirname "$destination_path")"
            cp "$source_path" "$destination_path"
            echo "  seeded: $relative_path"
            seeded=$((seeded + 1))
        fi
    done

    echo "Seeded $seeded file(s), skipped $skipped existing."
}

command_list() {
    if [[ ! -d "$LOCAL_DIR" ]]; then
        echo "No local config directory found."
        return 0
    fi

    if command -v tree > /dev/null 2>&1; then
        tree -a --noreport "$LOCAL_DIR"
    else
        list_relative_files "$LOCAL_DIR"
    fi
}

command_backup() {
    local default_directory="$DOTFILES_DIR/backups/$DOTFILES_TIMESTAMP"
    local output="${1:-$default_directory/local.enc}"
    local temp_archive

    require_command tar
    ensure_passphrase_with_confirmation
    mkdir -p "$(dirname "$output")"

    if [[ ! -d "$LOCAL_DIR" ]]; then
        echo "No local config to back up. Run 'dotfiles-local init' first." >&2
        exit 1
    fi

    temp_archive="$(mktemp)"
    trap 'rm -f "$temp_archive"' EXIT
    tar -cf "$temp_archive" -C "$DOTFILES_DIR" local

    encrypt_file "$temp_archive" "$output" DOTFILES_BACKUP_PASSPHRASE

    chmod 600 "$output"
    rm -f "$temp_archive"
    trap - EXIT
    echo "Backup written: $output"
}

command_restore() {
    local input=""
    local temp_archive extract_directory
    local overwrite=0

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
                input="$1"
                shift
                ;;
        esac
    done

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
    temp_archive="$(mktemp)"
    trap 'rm -f "${temp_archive:-}"; rm -rf "${extract_directory:-}"' EXIT

    decrypt_file "$input" "$temp_archive" DOTFILES_BACKUP_PASSPHRASE

    extract_directory="$(mktemp -d)"
    tar -xf "$temp_archive" -C "$extract_directory"
    rm -f "$temp_archive"

    if [[ ! -d "$extract_directory/local" ]]; then
        echo "Archive does not contain a local/ directory." >&2
        rm -rf "$extract_directory"
        exit 1
    fi

    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(list_relative_files "$extract_directory/local")

    if ! check_restore_conflicts "$overwrite" "$LOCAL_DIR" "${files[@]}"; then
        rm -rf "$extract_directory"
        exit 1
    fi

    mkdir -p "$LOCAL_DIR"
    for file in "${files[@]}"; do
        mkdir -p "$(dirname "$LOCAL_DIR/$file")"
        cp -p "$extract_directory/local/$file" "$LOCAL_DIR/$file"
    done

    rm -rf "$extract_directory"
    trap - EXIT
    echo "Restore complete to: $LOCAL_DIR"
}

main() {
    local subcommand="${1:-}"
    shift || true

    [[ "$subcommand" == "_completions" ]] && {
        echo "init list backup restore help"
        return
    }

    case "$subcommand" in
        init) command_init ;;
        list) command_list ;;
        backup)
            command_backup "$@"
            ;;
        restore)
            command_restore "$@"
            ;;
        "" | -h | --help | help)
            usage
            ;;
        *)
            echo "Unknown command: $subcommand" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"

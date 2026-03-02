#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"
source "$DOTFILES_DIR/scripts/lib/restore.sh"

LOCAL_DIR="$DOTFILES_DIR/local"
EXAMPLE_DIR="$DOTFILES_DIR/local.example"

list_relative_files() {
    local base_dir="$1"
    if command -v fd >/dev/null 2>&1; then
        fd -t f -HI --base-directory "$base_dir"
    else
        (
            cd "$base_dir"
            find . -type f -print | sed 's|^\./||'
        )
    fi
}

usage() {
    cat <<'EOF'
Usage:
  dotfiles-local init
  dotfiles-local list
  dotfiles-local backup [output.enc]
  dotfiles-local restore <input.enc>

Examples:
  dotfiles-local init
  dotfiles-local backup ~/local.enc
  DOTFILES_BACKUP_PASSPHRASE='strong-passphrase' dotfiles-local backup ~/local.enc
  dotfiles-local restore ~/local.enc
  DOTFILES_LOCAL_RESTORE_OVERWRITE=1 dotfiles-local restore ~/local.enc

Notes:
  - local/ holds machine-specific config (git identities, npm registries, secrets map)
  - local.example/ contains sanitized templates seeded on first install
  - Backup file is encrypted with AES-256-CBC + PBKDF2
EOF
}

cmd_init() {
    local seeded=0
    local skipped=0

    if [[ ! -d "$EXAMPLE_DIR" ]]; then
        echo "Template directory not found: $EXAMPLE_DIR" >&2
        exit 1
    fi

    while IFS= read -r relative_path; do
        local source_path="$EXAMPLE_DIR/$relative_path"
        local destination_path="$LOCAL_DIR/$relative_path"

        if [[ -e "$destination_path" ]]; then
            echo "  exists: $relative_path"
            skipped=$((skipped + 1))
        else
            mkdir -p "$(dirname "$destination_path")"
            cp "$source_path" "$destination_path"
            echo "  seeded: $relative_path"
            seeded=$((seeded + 1))
        fi
    done < <(list_relative_files "$EXAMPLE_DIR")

    echo "Seeded $seeded file(s), skipped $skipped existing."
}

cmd_list() {
    if [[ ! -d "$LOCAL_DIR" ]]; then
        echo "No local config directory found."
        return 0
    fi

    if command -v tree >/dev/null 2>&1; then
        tree -a --noreport "$LOCAL_DIR"
    else
        list_relative_files "$LOCAL_DIR"
    fi
}

cmd_backup() {
    local output="${1:-$HOME/local-$DOTFILES_TIMESTAMP.enc}"
    local tmp_archive

    require_cmd tar

    if [[ ! -d "$LOCAL_DIR" ]]; then
        echo "No local config to back up. Run 'dotfiles-local init' first." >&2
        exit 1
    fi

    tmp_archive="$(mktemp)"
    trap 'rm -f "$tmp_archive"' EXIT
    tar -cf "$tmp_archive" -C "$DOTFILES_DIR" local

    encrypt_file "$tmp_archive" "$output" DOTFILES_BACKUP_PASSPHRASE

    chmod 600 "$output"
    rm -f "$tmp_archive"
    trap - EXIT
    echo "Backup written: $output"
}

cmd_restore() {
    local input="${1:-}"
    local tmp_archive extract_dir
    local overwrite="${DOTFILES_LOCAL_RESTORE_OVERWRITE:-0}"

    require_cmd tar

    [[ -n "$input" ]] || {
        usage
        exit 1
    }
    [[ -f "$input" ]] || {
        echo "Backup not found: $input" >&2
        exit 1
    }

    tmp_archive="$(mktemp)"
    trap 'rm -f "${tmp_archive:-}"; rm -rf "${extract_dir:-}"' EXIT

    decrypt_file "$input" "$tmp_archive" DOTFILES_BACKUP_PASSPHRASE

    extract_dir="$(mktemp -d)"
    tar -xf "$tmp_archive" -C "$extract_dir"
    rm -f "$tmp_archive"

    if [[ ! -d "$extract_dir/local" ]]; then
        echo "Archive does not contain a local/ directory." >&2
        rm -rf "$extract_dir"
        exit 1
    fi

    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(list_relative_files "$extract_dir/local")

    if ! check_restore_conflicts "$overwrite" "$LOCAL_DIR" "DOTFILES_LOCAL_RESTORE_OVERWRITE" "${files[@]}"; then
        rm -rf "$extract_dir"
        exit 1
    fi

    mkdir -p "$LOCAL_DIR"
    while IFS= read -r file; do
        mkdir -p "$(dirname "$LOCAL_DIR/$file")"
        cp -p "$extract_dir/local/$file" "$LOCAL_DIR/$file"
    done < <(list_relative_files "$extract_dir/local")

    rm -rf "$extract_dir"
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
        init) cmd_init ;;
        list) cmd_list ;;
        backup)
            cmd_backup "$@"
            ;;
        restore)
            cmd_restore "$@"
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

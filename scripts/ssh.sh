#!/usr/bin/env bash
set -euo pipefail

# Encrypted backup/restore helper for SSH key material.
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"
source "$DOTFILES_DIR/scripts/lib/restore.sh"

usage() {
    cat <<'EOF'
Usage:
  dotfiles-ssh list [ssh_dir]
  dotfiles-ssh backup [output.enc] [ssh_dir]
  dotfiles-ssh restore <input.enc> [ssh_dir]

Examples:
  dotfiles-ssh list
  dotfiles-ssh backup ~/ssh-keys.enc
  DOTFILES_BACKUP_PASSPHRASE='strong-passphrase' dotfiles-ssh backup ~/ssh-keys.enc
  dotfiles-ssh restore ~/ssh-keys.enc
  DOTFILES_SSH_RESTORE_OVERWRITE=1 dotfiles-ssh restore ~/ssh-keys.enc

Notes:
  - Source/target ssh_dir defaults to ~/.ssh
  - Backup includes: id_* keys (private/public), known_hosts*, authorized_keys
  - Backup file is encrypted with AES-256-CBC + PBKDF2
EOF
}

collect_files() {
    # Emit relative file names that should be included in backup.
    local ssh_dir="$1"
    local pattern file
    local had_nullglob=0

    [[ -d "$ssh_dir" ]] || return 0

    shopt -q nullglob && had_nullglob=1
    shopt -s nullglob

    for pattern in 'id_*' 'known_hosts' 'known_hosts.old' 'authorized_keys'; do
        for file in "$ssh_dir"/$pattern; do
            [[ -f "$file" ]] || continue
            basename "$file"
        done
    done | sort -u

    if [[ "$had_nullglob" -eq 0 ]]; then
        shopt -u nullglob
    fi
}

set_file_permissions() {
    # Restore secure/default permissions based on SSH file type.
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

cmd_list() {
    local ssh_dir="${1:-$HOME/.ssh}"
    local files=()
    local file
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(collect_files "$ssh_dir")

    echo "ssh_dir: $ssh_dir"
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "No backup candidate files found."
        return 0
    fi

    for file in "${files[@]}"; do
        ls -l "$ssh_dir/$file"
    done
}

cmd_backup() {
    # Stage selected files and encrypt as a portable backup artifact.
    local output="${1:-$HOME/ssh-$DOTFILES_TIMESTAMP.enc}"
    local ssh_dir="${2:-$HOME/.ssh}"
    local files=()
    local tmp_dir stage_dir tar_file manifest_file
    local file

    require_cmd tar

    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(collect_files "$ssh_dir")
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "No backup candidate files found in $ssh_dir" >&2
        exit 1
    fi

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT
    stage_dir="$tmp_dir/ssh"
    tar_file="$tmp_dir/ssh-keys.tar"
    manifest_file="$stage_dir/MANIFEST.txt"
    mkdir -p "$stage_dir"

    for file in "${files[@]}"; do
        cp -p "$ssh_dir/$file" "$stage_dir/$file"
    done

    {
        echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "source_ssh_dir=$ssh_dir"
        echo "files:"
        for file in "${files[@]}"; do
            echo "  - $file"
        done
    } >"$manifest_file"

    tar -cf "$tar_file" -C "$tmp_dir" ssh

    encrypt_file "$tar_file" "$output" DOTFILES_BACKUP_PASSPHRASE

    chmod 600 "$output"
    rm -rf "$tmp_dir"
    trap - EXIT

    echo "Backup written: $output"
    echo "Files included: ${#files[@]}"
}

cmd_restore() {
    # Decrypt backup and restore files into target ~/.ssh directory.
    local input="${1:-}"
    local ssh_dir="${2:-$HOME/.ssh}"
    local tmp_dir tar_file extract_dir
    local overwrite="${DOTFILES_SSH_RESTORE_OVERWRITE:-0}"
    local file
    local entries=()

    require_cmd tar

    [[ -n "$input" ]] || {
        usage
        exit 1
    }
    [[ -f "$input" ]] || {
        echo "Backup not found: $input" >&2
        exit 1
    }

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT
    tar_file="$tmp_dir/ssh-keys.tar"
    extract_dir="$tmp_dir/extract"

    decrypt_file "$input" "$tar_file" DOTFILES_BACKUP_PASSPHRASE

    while IFS= read -r file; do
        entries+=("$file")
    done < <(tar -tf "$tar_file")

    if [[ "${#entries[@]}" -eq 0 ]]; then
        echo "Backup archive is empty." >&2
        rm -rf "$tmp_dir"
        exit 1
    fi

    for file in "${entries[@]}"; do
        [[ "$file" == ssh/* ]] || {
            echo "Unexpected path in archive: $file" >&2
            rm -rf "$tmp_dir"
            exit 1
        }
    done

    mkdir -p "$extract_dir"
    tar -xf "$tar_file" -C "$extract_dir"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    local restore_files=()
    while IFS= read -r file; do
        [[ "$file" == "MANIFEST.txt" ]] && continue
        [[ -f "$extract_dir/ssh/$file" ]] || continue
        restore_files+=("$file")
    done < <(ls -1 "$extract_dir/ssh")

    if ! check_restore_conflicts "$overwrite" "$ssh_dir" "DOTFILES_SSH_RESTORE_OVERWRITE" "${restore_files[@]}"; then
        rm -rf "$tmp_dir"
        exit 1
    fi

    while IFS= read -r file; do
        [[ "$file" == "MANIFEST.txt" ]] && continue
        [[ -f "$extract_dir/ssh/$file" ]] || continue
        cp -p "$extract_dir/ssh/$file" "$ssh_dir/$file"
        set_file_permissions "$ssh_dir/$file"
    done < <(ls -1 "$extract_dir/ssh")

    rm -rf "$tmp_dir"
    trap - EXIT
    echo "Restore complete to: $ssh_dir"
}

main() {
    local cmd="${1:-}"
    shift || true

    [[ "$cmd" == "_completions" ]] && {
        echo "list backup restore help"
        return
    }

    case "$cmd" in
        list) cmd_list "$@" ;;
        backup) cmd_backup "$@" ;;
        restore) cmd_restore "$@" ;;
        "" | -h | --help | help) usage ;;
        *)
            echo "Unknown command: $cmd" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"

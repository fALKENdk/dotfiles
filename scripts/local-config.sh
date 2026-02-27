#!/usr/bin/env bash
set -euo pipefail

# Manage machine-specific config in local/ (gitignored).
# Seed from templates, list contents, and encrypted backup/restore.
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"

LOCAL_DIR="$DOTFILES_DIR/local"
EXAMPLE_DIR="$DOTFILES_DIR/local.example"

usage() {
    cat <<'EOF'
Usage:
  local-config init
  local-config list
  local-config backup [output.enc]
  local-config restore <input.enc>

Examples:
  local-config init
  local-config backup ~/local-config.enc
  LOCAL_CONFIG_PASSPHRASE='strong-passphrase' local-config backup ~/local-config.enc
  local-config restore ~/local-config.enc
  LOCAL_CONFIG_RESTORE_OVERWRITE=1 local-config restore ~/local-config.enc

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

    while IFS= read -r rel_path; do
        local src="$EXAMPLE_DIR/$rel_path"
        local dst="$LOCAL_DIR/$rel_path"

        if [[ -e "$dst" ]]; then
            echo "  exists: $rel_path"
            skipped=$((skipped + 1))
        else
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            echo "  seeded: $rel_path"
            seeded=$((seeded + 1))
        fi
    done < <(fd -t f -HI --base-directory "$EXAMPLE_DIR")

    echo "Seeded $seeded file(s), skipped $skipped existing."
}

cmd_list() {
    if [[ ! -d "$LOCAL_DIR" ]]; then
        echo "No local config directory found."
        return 0
    fi

    tree -a --noreport "$LOCAL_DIR"
}

cmd_backup() {
    local output="${1:-$HOME/local-config-$(date +%Y%m%d-%H%M%S).enc}"
    local tmp_tar

    require_cmd tar

    if [[ ! -d "$LOCAL_DIR" ]]; then
        echo "No local config to back up. Run 'local-config init' first." >&2
        exit 1
    fi

    tmp_tar="$(mktemp)"
    trap 'rm -f "$tmp_tar"' EXIT
    tar -cf "$tmp_tar" -C "$DOTFILES_DIR" local

    encrypt_file "$tmp_tar" "$output" LOCAL_CONFIG_PASSPHRASE

    chmod 600 "$output"
    rm -f "$tmp_tar"
    trap - EXIT
    echo "Backup written: $output"
}

cmd_restore() {
    local input="${1:-}"
    local tmp_tar extract_dir
    local overwrite="${LOCAL_CONFIG_RESTORE_OVERWRITE:-0}"

    require_cmd tar

    [[ -n "$input" ]] || {
        usage
        exit 1
    }
    [[ -f "$input" ]] || {
        echo "Backup not found: $input" >&2
        exit 1
    }

    tmp_tar="$(mktemp)"
    trap 'rm -f "${tmp_tar:-}"; rm -rf "${extract_dir:-}"' EXIT

    decrypt_file "$input" "$tmp_tar" LOCAL_CONFIG_PASSPHRASE

    extract_dir="$(mktemp -d)"
    tar -xf "$tmp_tar" -C "$extract_dir"
    rm -f "$tmp_tar"

    if [[ ! -d "$extract_dir/local" ]]; then
        echo "Archive does not contain a local/ directory." >&2
        rm -rf "$extract_dir"
        exit 1
    fi

    local conflicts=()
    while IFS= read -r f; do
        if [[ -e "$LOCAL_DIR/$f" && "$overwrite" != "1" ]]; then
            conflicts+=("$f")
        fi
    done < <(fd -t f -HI --base-directory "$extract_dir/local")

    if [[ "${#conflicts[@]}" -gt 0 ]]; then
        echo "Restore aborted. Existing files would be overwritten:" >&2
        for f in "${conflicts[@]}"; do
            echo "  - local/$f" >&2
        done
        echo "Set LOCAL_CONFIG_RESTORE_OVERWRITE=1 to overwrite." >&2
        rm -rf "$extract_dir"
        exit 1
    fi

    mkdir -p "$LOCAL_DIR"
    while IFS= read -r f; do
        mkdir -p "$(dirname "$LOCAL_DIR/$f")"
        cp -p "$extract_dir/local/$f" "$LOCAL_DIR/$f"
    done < <(fd -t f -HI --base-directory "$extract_dir/local")

    rm -rf "$extract_dir"
    trap - EXIT
    echo "Restore complete to: $LOCAL_DIR"
}

main() {
    local cmd="${1:-}"
    shift || true

    [[ "$cmd" == "_completions" ]] && {
        echo "init list backup restore help"
        return
    }

    case "$cmd" in
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
            echo "Unknown command: $cmd" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2> /dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"
source "$DOTFILES_DIR/scripts/lib/format.sh"
source "$DOTFILES_DIR/scripts/lib/secrets-store.sh"
source "$DOTFILES_DIR/scripts/lib/secrets-map.sh"

usage() {
    cat << EOF
Usage:
  dotfiles-secrets list
  dotfiles-secrets doctor
  dotfiles-secrets env
  dotfiles-secrets set <ENV_VAR> <value>
  dotfiles-secrets get <ENV_VAR>
  dotfiles-secrets delete <ENV_VAR>
  dotfiles-secrets backup [output.enc]
  dotfiles-secrets restore <input.enc>

Examples:
  dotfiles-secrets list
  dotfiles-secrets doctor
  dotfiles-secrets set AZURE_NPM_USERNAME "your-username"
  dotfiles-secrets backup
  dotfiles-secrets restore backups/20260302-120000/secrets.enc

Notes:
  - Mapping file: $SECRETS_MAP_FILE
  - Active store: ${DOTFILES_SECRETS_STORE:-undetected}
  - OWNER in mapping accepts "__USER__" (or empty), resolved at runtime
  - Use DOTFILES_SECRETS_MAP_FILE to override mapping path
  - Store: DOTFILES_SECRETS_STORE=auto|security|pass (default: auto)
  - Pass store path prefix: DOTFILES_PASS_PREFIX (default: dotfiles)
  - Set DOTFILES_BACKUP_PASSPHRASE for non-interactive backup/restore
  - restore will add missing map entries into local/secrets/secrets-map.json
EOF
}

command_list() {
    local env_var label owner note resolved_owner owner_template
    {
        printf 'ENV_VAR\tLABEL\tOWNER\tOWNER_RESOLVED\tNOTE\n'
        while IFS=$'\t' read -r env_var label owner note; do
            [[ -z "$env_var" || -z "$label" ]] && continue
            resolved_owner="$(resolve_owner "$owner")"
            owner_template="$owner"
            [[ -z "$owner_template" ]] && owner_template="__USER__"
            printf '%s\t%s\t%s\t%s\t%s\n' \
                "$env_var" "$label" "$owner_template" "$resolved_owner" "$note"
        done < <(emit_map_entries)
    } | render_tabular
}

command_doctor() {
    local present=0
    local missing=0
    local temp_table

    _doctor_row() {
        local env_var="$1"
        local label="$2"
        local owner="$3"
        local state

        if secret_exists "$label" "$owner"; then
            state="present"
            present=$((present + 1))
        else
            state="missing"
            missing=$((missing + 1))
        fi
        printf '%s\t%s\t%s\n' "$state" "$env_var" "$label"
    }

    temp_table="$(mktemp)"
    printf 'STATE\tENV_VAR\tLABEL\n' > "$temp_table"
    for_each_map_entry _doctor_row >> "$temp_table"
    render_tabular < "$temp_table"
    rm -f "$temp_table"
    echo "present=$present missing=$missing"
}

command_env() {
    _env_row() {
        local env_var="$1"
        local label="$2"
        local owner="$3"
        local value

        value="$(secret_get "$label" "$owner")"
        if [[ -n "$value" ]]; then
            printf 'export %s=%q\n' "$env_var" "$value"
        fi
    }
    for_each_map_entry _env_row
}

# Resolve a map entry by ENV_VAR and populate ENTRY_LABEL / ENTRY_OWNER globals.
resolve_entry() {
    local env_var="${1:-}"
    local row
    [[ -n "$env_var" ]] || {
        usage
        exit 1
    }
    row="$(find_entry_by_env_var "$env_var")" || {
        echo "Unknown ENV_VAR: $env_var" >&2
        exit 1
    }
    local _env_var _note
    IFS=$'\t' read -r _env_var ENTRY_LABEL ENTRY_OWNER _note <<< "$row"
}

command_set() {
    local env_var="${1:-}"
    local value="${2:-}"

    [[ -n "$env_var" && -n "$value" ]] || {
        usage
        exit 1
    }
    resolve_entry "$env_var"
    secret_set "$ENTRY_LABEL" "$ENTRY_OWNER" "$value"
    echo "Stored $env_var in store '$DOTFILES_SECRETS_STORE' (label: $ENTRY_LABEL)"
}

command_get() {
    local env_var="${1:-}"
    resolve_entry "$env_var"
    local value
    value="$(secret_get "$ENTRY_LABEL" "$ENTRY_OWNER")"
    if [[ -z "$value" ]]; then
        echo "No secret found for $env_var (label: $ENTRY_LABEL)" >&2
        exit 1
    fi
    printf '%s\n' "$value"
}

command_delete() {
    local env_var="${1:-}"
    resolve_entry "$env_var"
    secret_delete "$ENTRY_LABEL" "$ENTRY_OWNER"
    echo "Deleted $env_var from store '$DOTFILES_SECRETS_STORE' (label: $ENTRY_LABEL)"
}

command_backup() {
    local default_directory="$DOTFILES_DIR/backups/$DOTFILES_TIMESTAMP"
    local output="${1:-$default_directory/secrets.enc}"
    local temp_plaintext
    local written=0

    ensure_passphrase
    mkdir -p "$(dirname "$output")"
    temp_plaintext="$(mktemp)"
    trap 'rm -f "$temp_plaintext"' EXIT

    _backup_row() {
        local env_var="$1"
        local label="$2"
        local owner="$3"
        local _note="$4"
        local value value_base64

        value="$(secret_get "$label" "$owner")"
        if [[ -z "$value" ]]; then
            return 0
        fi

        value_base64="$(printf '%s' "$value" | base64 | tr -d '\n')"
        printf '%s\t%s\t%s\t%s\n' "$env_var" "$label" "$owner" "$value_base64" >> "$temp_plaintext"
        written=$((written + 1))
    }

    for_each_map_entry _backup_row

    if [[ "$written" -eq 0 ]]; then
        rm -f "$temp_plaintext"
        echo "No secrets found to back up." >&2
        exit 1
    fi

    encrypt_file "$temp_plaintext" "$output" DOTFILES_BACKUP_PASSPHRASE

    rm -f "$temp_plaintext"
    trap - EXIT
    echo "Backup written: $output"
}

command_restore() {
    local input="${1:-}"
    local temp_plaintext
    local restored=0
    local map_entries_added=0
    local owner_template resolved_owner
    [[ -n "$input" ]] || {
        usage
        exit 1
    }
    [[ -f "$input" ]] || {
        echo "Backup not found: $input" >&2
        exit 1
    }

    ensure_passphrase
    temp_plaintext="$(mktemp)"
    trap 'rm -f "$temp_plaintext"' EXIT

    decrypt_file "$input" "$temp_plaintext" DOTFILES_BACKUP_PASSPHRASE

    while IFS=$'\t' read -r env_var label owner value_base64; do
        [[ -z "$env_var" || -z "$label" || -z "$owner" || -z "$value_base64" ]] && continue
        value="$(printf '%s' "$value_base64" | base64 -d 2> /dev/null || printf '%s' "$value_base64" | base64 -D 2> /dev/null || true)"
        [[ -z "$value" ]] && continue

        owner_template="$(normalize_owner_template "$owner")"
        resolved_owner="$(resolve_owner "$owner_template")"

        secret_set "$label" "$resolved_owner" "$value"
        ensure_map_entry "$env_var" "$label" "$owner_template" "" && map_entries_added=$((map_entries_added + 1))
        restored=$((restored + 1))
    done < "$temp_plaintext"

    rm -f "$temp_plaintext"
    trap - EXIT
    echo "Restored entries: $restored (map entries added: $map_entries_added)"
}

main() {
    local subcommand="${1:-}"
    shift || true

    [[ "$subcommand" == "_completions" ]] && {
        echo "list doctor env set get delete backup restore help"
        return
    }

    require_command jq
    [[ "$subcommand" == "restore" ]] && ensure_map_file
    require_map
    detect_store
    require_store

    case "$subcommand" in
        list) command_list "$@" ;;
        doctor) command_doctor "$@" ;;
        env) command_env "$@" ;;
        set) command_set "$@" ;;
        get) command_get "$@" ;;
        delete) command_delete "$@" ;;
        backup) command_backup "$@" ;;
        restore) command_restore "$@" ;;
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

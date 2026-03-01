#!/usr/bin/env bash
set -euo pipefail

# Unified secrets CLI with pluggable backends:
# - macOS Keychain (`security`)
# - pass password store (`pass`)
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"
source "$DOTFILES_DIR/scripts/lib/secrets-store.sh"
source "$DOTFILES_DIR/scripts/lib/secrets-map.sh"

usage() {
    cat <<EOF
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
  dotfiles-secrets backup ~/secrets.enc
  dotfiles-secrets restore ~/secrets.enc

Notes:
  - Mapping file: $MAP_FILE
  - Active backend: ${SECRET_BACKEND:-undetected}
  - ACCOUNT in mapping accepts "__USER__" (or empty), resolved at runtime
  - Use DOTFILES_MAP_FILE to override mapping path
  - Backend: DOTFILES_SECRETS_BACKEND=auto|security|pass (default: auto)
  - Pass backend path prefix: DOTFILES_PASS_PREFIX (default: dotfiles-secrets)
  - Set DOTFILES_BACKUP_PASSPHRASE for non-interactive backup/restore
  - restore will add missing map entries into local/secrets/secrets-map.json
EOF
}

cmd_list() {
    local env_var service account note resolved_account account_template
    {
        printf 'ENV_VAR\tSERVICE\tACCOUNT\tACCOUNT_RESOLVED\tNOTE\n'
        while IFS=$'\t' read -r env_var service account note; do
            [[ -z "$env_var" || -z "$service" ]] && continue
            resolved_account="$(resolve_account "$account")"
            account_template="$account"
            [[ -z "$account_template" ]] && account_template="__USER__"
            printf '%s\t%s\t%s\t%s\t%s\n' \
                "$env_var" "$service" "$account_template" "$resolved_account" "$note"
        done < <(emit_map_entries)
    } | render_tabular
}

cmd_doctor() {
    local present=0
    local missing=0
    local tmp_table

    _doctor_row() {
        local env_var="$1"
        local service="$2"
        local account="$3"
        local state

        if secret_exists "$service" "$account"; then
            state="present"
            present=$((present + 1))
        else
            state="missing"
            missing=$((missing + 1))
        fi
        printf '%s\t%s\t%s\n' "$state" "$env_var" "$service"
    }

    tmp_table="$(mktemp)"
    printf 'STATE\tENV_VAR\tSERVICE\n' >"$tmp_table"
    for_each_map_entry _doctor_row >>"$tmp_table"
    render_tabular <"$tmp_table"
    rm -f "$tmp_table"
    echo "present=$present missing=$missing"
}

cmd_env() {
    _env_row() {
        local env_var="$1"
        local service="$2"
        local account="$3"
        local value

        value="$(secret_get "$service" "$account")"
        if [[ -n "$value" ]]; then
            printf 'export %s=%q\n' "$env_var" "$value"
        fi
    }
    for_each_map_entry _env_row
}

# Resolve a map entry by ENV_VAR and populate ENTRY_* globals.
#
# @param $1 env_var - ENV_VAR name to look up
# @global ENTRY_SERVICE  - resolved service name
# @global ENTRY_ACCOUNT  - resolved account name
# @throws exits 1 if env_var is empty or not found
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
    local _var _note
    IFS=$'\t' read -r _var ENTRY_SERVICE ENTRY_ACCOUNT _note <<<"$row"
}

cmd_set() {
    local env_var="${1:-}"
    local value="${2:-}"

    [[ -n "$env_var" && -n "$value" ]] || {
        usage
        exit 1
    }
    resolve_entry "$env_var"
    secret_set "$ENTRY_SERVICE" "$ENTRY_ACCOUNT" "$value"
    echo "Stored $env_var in backend '$SECRET_BACKEND' (service: $ENTRY_SERVICE)"
}

cmd_get() {
    local env_var="${1:-}"
    resolve_entry "$env_var"
    local value
    value="$(secret_get "$ENTRY_SERVICE" "$ENTRY_ACCOUNT")"
    if [[ -z "$value" ]]; then
        echo "No secret found for $env_var (service: $ENTRY_SERVICE)" >&2
        exit 1
    fi
    printf '%s\n' "$value"
}

cmd_delete() {
    local env_var="${1:-}"
    resolve_entry "$env_var"
    secret_delete "$ENTRY_SERVICE" "$ENTRY_ACCOUNT"
    echo "Deleted $env_var from backend '$SECRET_BACKEND' (service: $ENTRY_SERVICE)"
}

cmd_backup() {
    local output="${1:-$HOME/secrets-$DOTFILES_TIMESTAMP.enc}"
    local tmp_plain
    local written=0
    tmp_plain="$(mktemp)"
    trap 'rm -f "$tmp_plain"' EXIT

    _backup_row() {
        local env_var="$1"
        local service="$2"
        local account="$3"
        local _note="$4"
        local value value_b64

        value="$(secret_get "$service" "$account")"
        if [[ -z "$value" ]]; then
            return 0
        fi

        value_b64="$(printf '%s' "$value" | base64 | tr -d '\n')"
        printf '%s\t%s\t%s\t%s\n' "$env_var" "$service" "$account" "$value_b64" >>"$tmp_plain"
        written=$((written + 1))
    }

    for_each_map_entry _backup_row

    if [[ "$written" -eq 0 ]]; then
        rm -f "$tmp_plain"
        echo "No secrets found to back up." >&2
        exit 1
    fi

    encrypt_file "$tmp_plain" "$output" DOTFILES_BACKUP_PASSPHRASE

    rm -f "$tmp_plain"
    trap - EXIT
    echo "Backup written: $output"
}

cmd_restore() {
    local input="${1:-}"
    local tmp_plain
    local restored=0
    local map_added=0
    local account_template resolved_account
    [[ -n "$input" ]] || {
        usage
        exit 1
    }
    [[ -f "$input" ]] || {
        echo "Backup not found: $input" >&2
        exit 1
    }

    tmp_plain="$(mktemp)"
    trap 'rm -f "$tmp_plain"' EXIT

    decrypt_file "$input" "$tmp_plain" DOTFILES_BACKUP_PASSPHRASE

    while IFS=$'\t' read -r env_var service account value_b64; do
        [[ -z "$env_var" || -z "$service" || -z "$account" || -z "$value_b64" ]] && continue
        value="$(printf '%s' "$value_b64" | base64 -d 2>/dev/null || printf '%s' "$value_b64" | base64 -D 2>/dev/null || true)"
        [[ -z "$value" ]] && continue

        account_template="$(normalize_account_template "$account")"
        resolved_account="$(resolve_account "$account_template")"

        secret_set "$service" "$resolved_account" "$value"
        ensure_map_entry "$env_var" "$service" "$account_template" "" && map_added=$((map_added + 1))
        restored=$((restored + 1))
    done <"$tmp_plain"

    rm -f "$tmp_plain"
    trap - EXIT
    echo "Restored entries: $restored (map entries added: $map_added)"
}

main() {
    local cmd="${1:-}"
    shift || true

    [[ "$cmd" == "_completions" ]] && {
        echo "list doctor env set get delete backup restore help"
        return
    }

    require_cmd jq
    [[ "$cmd" == "restore" ]] && ensure_map_file
    require_map
    detect_backend
    require_backend

    case "$cmd" in
        list) cmd_list "$@" ;;
        doctor) cmd_doctor "$@" ;;
        env) cmd_env "$@" ;;
        set) cmd_set "$@" ;;
        get) cmd_get "$@" ;;
        delete) cmd_delete "$@" ;;
        backup) cmd_backup "$@" ;;
        restore) cmd_restore "$@" ;;
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

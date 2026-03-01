#!/usr/bin/env bash
set -euo pipefail

# Unified secrets CLI with pluggable backends:
# - macOS Keychain (`security`)
# - pass password store (`pass`)
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"
source "$DOTFILES_DIR/scripts/lib/crypto.sh"
MAP_FILE="${KEYCHAIN_MAP_FILE:-$DOTFILES_DIR/local/secrets/secrets-map.json}"
KEYCHAIN_SECRETS_BACKEND="${KEYCHAIN_SECRETS_BACKEND:-auto}"
KEYCHAIN_PASS_PREFIX="${KEYCHAIN_PASS_PREFIX:-dotfiles-secrets}"
SECRET_BACKEND=""

usage() {
    cat <<EOF
Usage:
  keychain-secrets list [collection|all]
  keychain-secrets doctor [collection|all]
  keychain-secrets env [collection|all]
  keychain-secrets set <ENV_VAR> <value>
  keychain-secrets get <ENV_VAR>
  keychain-secrets delete <ENV_VAR>
  keychain-secrets backup [collection|all] [output.enc]
  keychain-secrets restore <input.enc>

Examples:
  keychain-secrets list
  keychain-secrets doctor development
  keychain-secrets set AZURE_NPM_USERNAME "your-username"
  keychain-secrets backup all ~/keychain-all.enc
  keychain-secrets restore ~/keychain-all.enc

Notes:
  - Mapping file: $MAP_FILE
  - Active backend: ${SECRET_BACKEND:-undetected}
  - ACCOUNT in mapping accepts "__USER__" (or empty), resolved at runtime
  - Use KEYCHAIN_MAP_FILE to override mapping path
  - Backend: KEYCHAIN_SECRETS_BACKEND=auto|security|pass (default: auto)
  - Pass backend path prefix: KEYCHAIN_PASS_PREFIX (default: dotfiles-secrets)
  - Set KEYCHAIN_BACKUP_PASSPHRASE for non-interactive backup/restore
  - restore will add missing map entries into local/secrets/secrets-map.json
EOF
}

# Validate that MAP_FILE exists and contains a JSON array of entries.
#
# @global MAP_FILE
# @throws exits 1 if file is missing or malformed
require_map() {
    if [[ ! -f "$MAP_FILE" ]]; then
        echo "Map file not found: $MAP_FILE" >&2
        exit 1
    fi

    if ! jq -e '
        (.entries // .) as $entries |
        ($entries | type == "array") and
        all(
            $entries[];
            (type == "object") and
            (.collection and .env_var and .service) and
            (.env_var | test("^[A-Za-z_][A-Za-z0-9_]*$"))
        )
    ' "$MAP_FILE" >/dev/null 2>&1; then
        echo "Invalid map file (expected JSON with entries array): $MAP_FILE" >&2
        echo "Each entry must include collection/env_var/service, and env_var must be a valid shell identifier." >&2
        exit 1
    fi
}

ensure_map_file() {
    # Create an empty map file when missing (used by restore flow).
    if [[ -f "$MAP_FILE" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$MAP_FILE")"
    cat >"$MAP_FILE" <<'EOF'
{
  "entries": []
}
EOF
}

detect_backend() {
    # Select active backend from explicit setting or environment auto-detect.
    case "$KEYCHAIN_SECRETS_BACKEND" in
    security | pass)
        SECRET_BACKEND="$KEYCHAIN_SECRETS_BACKEND"
        ;;
    auto | "")
        if command -v security >/dev/null 2>&1; then
            SECRET_BACKEND="security"
        elif command -v pass >/dev/null 2>&1; then
            SECRET_BACKEND="pass"
        else
            echo "No supported secrets backend found. Install macOS 'security' (default) or 'pass'." >&2
            exit 1
        fi
        ;;
    *)
        echo "Invalid KEYCHAIN_SECRETS_BACKEND: $KEYCHAIN_SECRETS_BACKEND" >&2
        exit 1
        ;;
    esac
}

require_backend() {
    # Validate required backend binary is installed.
    case "$SECRET_BACKEND" in
    security) require_cmd security ;;
    pass) require_cmd pass ;;
    *)
        echo "Unsupported backend: $SECRET_BACKEND" >&2
        exit 1
        ;;
    esac
}

pass_secret_path() {
    # Build pass path as: <prefix>/<service>/<account>.
    local service="$1"
    local account="$2"
    printf '%s/%s/%s' "$KEYCHAIN_PASS_PREFIX" "$service" "$account"
}

secret_exists() {
    # Return success when a mapped secret exists in active backend.
    local service="$1"
    local account="$2"

    case "$SECRET_BACKEND" in
    security)
        security find-generic-password -a "$account" -s "$service" >/dev/null 2>&1
        ;;
    pass)
        pass show "$(pass_secret_path "$service" "$account")" >/dev/null 2>&1
        ;;
    *)
        return 1
        ;;
    esac
}

secret_get() {
    # Read secret value from active backend.
    local service="$1"
    local account="$2"

    case "$SECRET_BACKEND" in
    security)
        security find-generic-password -a "$account" -s "$service" -w 2>/dev/null || true
        ;;
    pass)
        pass show "$(pass_secret_path "$service" "$account")" 2>/dev/null | awk 'NR==1{print; exit}' || true
        ;;
    *)
        return 1
        ;;
    esac
}

secret_set() {
    # Write secret value to active backend.
    local service="$1"
    local account="$2"
    local value="$3"
    local path

    case "$SECRET_BACKEND" in
    security)
        security add-generic-password -a "$account" -s "$service" -w "$value" -U >/dev/null
        ;;
    pass)
        path="$(pass_secret_path "$service" "$account")"
        printf '%s\n' "$value" | pass insert -m -f "$path" >/dev/null
        ;;
    *)
        return 1
        ;;
    esac
}

secret_delete() {
    # Delete secret entry from active backend.
    local service="$1"
    local account="$2"
    local path

    case "$SECRET_BACKEND" in
    security)
        security delete-generic-password -a "$account" -s "$service" >/dev/null 2>&1 || true
        ;;
    pass)
        path="$(pass_secret_path "$service" "$account")"
        pass rm -f "$path" >/dev/null 2>&1 || true
        ;;
    *)
        return 1
        ;;
    esac
}

# Resolve the account field: "__USER__" or empty becomes the current OS user.
#
# @param $1 account - account string from secrets map
# @return stdout - resolved account name
resolve_account() {
    local account="$1"
    if [[ -z "$account" || "$account" == "__USER__" ]]; then
        if [[ -n "${USER:-}" ]]; then
            printf '%s' "$USER"
        else
            id -un
        fi
    else
        printf '%s' "$account"
    fi
}

render_tabular() {
    # Render TSV as an aligned table when `column` is available.
    if command -v column >/dev/null 2>&1; then
        column -t -s $'\t'
    else
        cat
    fi
}

# Emit filtered map entries as tab-separated lines:
# collection \t env_var \t service \t account \t note
#
# @param $1 filter - collection name or "all" (default: "all")
# @return stdout - TSV lines
emit_map_entries() {
    local filter="${1:-all}"
    jq -r --arg wanted "$filter" '
    (.entries // .) | if type == "array" then . else [] end | .[] |
    select(type == "object") |
    select(.collection and .env_var and .service) |
    select($wanted == "all" or .collection == $wanted) |
    [.collection, .env_var, .service, (.account // ""), (.note // "")] |
    map(tostring) | join("\t")
  ' "$MAP_FILE"
}

# Iterate map entries and call a function for each.
# The callback receives: collection env_var service account note
#
# @param $1 callback - function name to call per entry
# @param $2 filter   - collection name or "all" (default: "all")
for_each_map_entry() {
    local callback="$1"
    local filter="${2:-all}"

    while IFS=$'\t' read -r collection env_var service account note; do
        [[ -z "$collection" || -z "$env_var" || -z "$service" ]] && continue
        account="$(resolve_account "$account")"
        "$callback" "$collection" "$env_var" "$service" "$account" "$note"
    done < <(emit_map_entries "$filter")
}

# Look up a single map entry by its env_var field.
#
# @param  $1 target - ENV_VAR name to search for
# @return stdout - TSV row (collection \t env_var \t service \t account \t note)
# @return 1 if not found
find_entry_by_env_var() {
    local target="$1"
    while IFS=$'\t' read -r collection env_var service account note; do
        [[ -z "$collection" || -z "$env_var" || -z "$service" ]] && continue
        if [[ "$env_var" == "$target" ]]; then
            account="$(resolve_account "$account")"
            printf '%s\t%s\t%s\t%s\t%s\n' "$collection" "$env_var" "$service" "$account" "$note"
            return 0
        fi
    done < <(emit_map_entries all)

    return 1
}

normalize_account_template() {
    local account="$1"
    if [[ -z "$account" || (-n "${USER:-}" && "$account" == "$USER") ]]; then
        # Keep restored maps portable across machines/usernames.
        printf '%s' "__USER__"
    else
        printf '%s' "$account"
    fi
}

ensure_map_entry() {
    local collection="$1"
    local env_var="$2"
    local service="$3"
    local account_template="$4"
    local note="${5:-}"
    local tmp_map

    if jq -e \
        --arg collection "$collection" \
        --arg env_var "$env_var" \
        --arg service "$service" \
        '
        (.entries // .) as $entries |
        ($entries | if type == "array" then . else [] end) as $arr |
        any($arr[]; .collection == $collection and .env_var == $env_var and .service == $service)
    ' "$MAP_FILE" >/dev/null 2>&1; then
        return 1
    fi

    tmp_map="$(mktemp)"
    jq \
        --arg collection "$collection" \
        --arg env_var "$env_var" \
        --arg service "$service" \
        --arg account "$account_template" \
        --arg note "$note" \
        '
        (.entries // .) as $entries |
        ($entries | if type == "array" then . else [] end) as $arr |
        {
            entries: (
                $arr + [{
                    collection: $collection,
                    env_var: $env_var,
                    service: $service,
                    account: $account,
                    note: $note
                }]
            )
        }
    ' "$MAP_FILE" >"$tmp_map"
    mv "$tmp_map" "$MAP_FILE"
    return 0
}

cmd_list() {
    local filter="${1:-all}"
    local collection env_var service account note resolved_account account_template
    {
        printf 'COLLECTION\tENV_VAR\tSERVICE\tACCOUNT\tACCOUNT_RESOLVED\tNOTE\n'
        while IFS=$'\t' read -r collection env_var service account note; do
            [[ -z "$collection" || -z "$env_var" || -z "$service" ]] && continue
            resolved_account="$(resolve_account "$account")"
            account_template="$account"
            [[ -z "$account_template" ]] && account_template="__USER__"
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$collection" "$env_var" "$service" "$account_template" "$resolved_account" "$note"
        done < <(emit_map_entries "$filter")
    } | render_tabular
}

cmd_doctor() {
    local filter="${1:-all}"
    local present=0
    local missing=0
    local tmp_table

    _doctor_row() {
        local collection="$1"
        local env_var="$2"
        local service="$3"
        local account="$4"
        local state

        if secret_exists "$service" "$account"; then
            state="present"
            present=$((present + 1))
        else
            state="missing"
            missing=$((missing + 1))
        fi
        printf '%s\t%s\t%s\t%s\n' "$state" "$collection" "$env_var" "$service"
    }

    tmp_table="$(mktemp)"
    printf 'STATE\tCOLLECTION\tENV_VAR\tSERVICE\n' >"$tmp_table"
    for_each_map_entry _doctor_row "$filter" >>"$tmp_table"
    render_tabular <"$tmp_table"
    rm -f "$tmp_table"
    echo "present=$present missing=$missing"
}

cmd_env() {
    local filter="${1:-all}"
    _env_row() {
        local _collection="$1"
        local env_var="$2"
        local service="$3"
        local account="$4"
        local value

        value="$(secret_get "$service" "$account")"
        if [[ -n "$value" ]]; then
            printf 'export %s=%q\n' "$env_var" "$value"
        fi
    }
    for_each_map_entry _env_row "$filter"
}

cmd_set() {
    local env_var="${1:-}"
    local value="${2:-}"
    local row collection _var service account _note

    [[ -n "$env_var" && -n "$value" ]] || {
        usage
        exit 1
    }
    row="$(find_entry_by_env_var "$env_var")" || {
        echo "Unknown ENV_VAR: $env_var" >&2
        exit 1
    }
    IFS=$'\t' read -r collection _var service account _note <<<"$row"

    secret_set "$service" "$account" "$value"
    echo "Stored $env_var in backend '$SECRET_BACKEND' (service: $service)"
}

cmd_get() {
    local env_var="${1:-}"
    local row collection _var service account _note
    [[ -n "$env_var" ]] || {
        usage
        exit 1
    }
    row="$(find_entry_by_env_var "$env_var")" || {
        echo "Unknown ENV_VAR: $env_var" >&2
        exit 1
    }
    IFS=$'\t' read -r collection _var service account _note <<<"$row"
    value="$(secret_get "$service" "$account")"
    if [[ -z "$value" ]]; then
        echo "No secret found for $env_var (service: $service)" >&2
        exit 1
    fi
    printf '%s\n' "$value"
}

cmd_delete() {
    local env_var="${1:-}"
    local row collection _var service account _note
    [[ -n "$env_var" ]] || {
        usage
        exit 1
    }
    row="$(find_entry_by_env_var "$env_var")" || {
        echo "Unknown ENV_VAR: $env_var" >&2
        exit 1
    }
    IFS=$'\t' read -r collection _var service account _note <<<"$row"
    secret_delete "$service" "$account"
    echo "Deleted $env_var from backend '$SECRET_BACKEND' (service: $service)"
}

cmd_backup() {
    local filter="${1:-all}"
    local output="${2:-$HOME/keychain-secrets-${filter}-$(date +%Y%m%d-%H%M%S).enc}"
    local tmp_plain
    local written=0
    tmp_plain="$(mktemp)"
    trap 'rm -f "$tmp_plain"' EXIT

    _backup_row() {
        local collection="$1"
        local env_var="$2"
        local service="$3"
        local account="$4"
        local _note="$5"
        local value value_b64

        value="$(secret_get "$service" "$account")"
        if [[ -z "$value" ]]; then
            return 0
        fi

        value_b64="$(printf '%s' "$value" | base64 | tr -d '\n')"
        printf '%s\t%s\t%s\t%s\t%s\n' "$collection" "$env_var" "$service" "$account" "$value_b64" >>"$tmp_plain"
        written=$((written + 1))
    }

    for_each_map_entry _backup_row "$filter"

    if [[ "$written" -eq 0 ]]; then
        rm -f "$tmp_plain"
        echo "No secrets found to back up for filter: $filter" >&2
        exit 1
    fi

    encrypt_file "$tmp_plain" "$output" KEYCHAIN_BACKUP_PASSPHRASE

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

    decrypt_file "$input" "$tmp_plain" KEYCHAIN_BACKUP_PASSPHRASE

    while IFS=$'\t' read -r collection env_var service account value_b64; do
        [[ -z "$collection" || -z "$env_var" || -z "$service" || -z "$account" || -z "$value_b64" ]] && continue
        value="$(printf '%s' "$value_b64" | base64 -d 2>/dev/null || printf '%s' "$value_b64" | base64 -D 2>/dev/null || true)"
        [[ -z "$value" ]] && continue

        account_template="$(normalize_account_template "$account")"
        resolved_account="$(resolve_account "$account_template")"

        secret_set "$service" "$resolved_account" "$value"
        ensure_map_entry "$collection" "$env_var" "$service" "$account_template" "" && map_added=$((map_added + 1))
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

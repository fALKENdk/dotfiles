#!/usr/bin/env bash
set -euo pipefail

# Secrets map helpers: validate, iterate, and update the JSON mapping
# between environment variables and backend entries.
#
# @global MAP_FILE - path to secrets-map.json

MAP_FILE="${DOTFILES_MAP_FILE:-$DOTFILES_DIR/local/secrets/secrets-map.json}"

# Validate that MAP_FILE exists and contains a well-formed entries array.
#
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
            (.env_var and .service) and
            (.env_var | test("^[A-Za-z_][A-Za-z0-9_]*$"))
        )
    ' "$MAP_FILE" >/dev/null 2>&1; then
        echo "Invalid map file (expected JSON with entries array): $MAP_FILE" >&2
        echo "Each entry must include env_var/service, and env_var must be a valid shell identifier." >&2
        exit 1
    fi
}

# Create an empty map file when missing (used by restore flow).
ensure_map_file() {
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

# Normalize an account value back to the portable template form.
normalize_account_template() {
    local account="$1"
    if [[ -z "$account" || (-n "${USER:-}" && "$account" == "$USER") ]]; then
        printf '%s' "__USER__"
    else
        printf '%s' "$account"
    fi
}

# Render TSV as an aligned table when `column` is available.
render_tabular() {
    if command -v column >/dev/null 2>&1; then
        column -t -s $'\t'
    else
        cat
    fi
}

# Emit map entries as tab-separated lines:
# env_var \t service \t account \t note
#
# @return stdout - TSV lines
emit_map_entries() {
    jq -r '
    (.entries // .) | if type == "array" then . else [] end | .[] |
    select(type == "object") |
    select(.env_var and .service) |
    [.env_var, .service, (.account // ""), (.note // "")] |
    map(tostring) | join("\t")
  ' "$MAP_FILE"
}

# Iterate map entries and call a function for each.
# The callback receives: env_var service account note
#
# @param $1 callback - function name to call per entry
for_each_map_entry() {
    local callback="$1"

    while IFS=$'\t' read -r env_var service account note; do
        [[ -z "$env_var" || -z "$service" ]] && continue
        account="$(resolve_account "$account")"
        "$callback" "$env_var" "$service" "$account" "$note"
    done < <(emit_map_entries)
}

# Look up a single map entry by its env_var field.
#
# @param  $1 target - ENV_VAR name to search for
# @return stdout - TSV row (env_var \t service \t account \t note)
# @return 1 if not found
find_entry_by_env_var() {
    local target="$1"
    while IFS=$'\t' read -r env_var service account note; do
        [[ -z "$env_var" || -z "$service" ]] && continue
        if [[ "$env_var" == "$target" ]]; then
            account="$(resolve_account "$account")"
            printf '%s\t%s\t%s\t%s\n' "$env_var" "$service" "$account" "$note"
            return 0
        fi
    done < <(emit_map_entries)

    return 1
}

# Add a map entry if it doesn't already exist.
# Returns 1 (without error) if the entry already exists.
#
# @param $1 env_var          - environment variable name
# @param $2 service          - backend service identifier
# @param $3 account_template - account (or "__USER__")
# @param $4 note             - optional description
ensure_map_entry() {
    local env_var="$1"
    local service="$2"
    local account_template="$3"
    local note="${4:-}"
    local tmp_map

    if jq -e \
        --arg env_var "$env_var" \
        --arg service "$service" \
        '
        (.entries // .) as $entries |
        ($entries | if type == "array" then . else [] end) as $arr |
        any($arr[]; .env_var == $env_var and .service == $service)
    ' "$MAP_FILE" >/dev/null 2>&1; then
        return 1
    fi

    tmp_map="$(mktemp)"
    jq \
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

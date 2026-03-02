#!/usr/bin/env bash
set -euo pipefail

SECRETS_MAP_FILE="${DOTFILES_SECRETS_MAP_FILE:-$DOTFILES_DIR/local/secrets/secrets-map.json}"

require_map() {
    if [[ ! -f "$SECRETS_MAP_FILE" ]]; then
        echo "Map file not found: $SECRETS_MAP_FILE" >&2
        exit 1
    fi

    if ! jq -e '
        (.entries // .) as $entries |
        ($entries | type == "array") and
        all(
            $entries[];
            (type == "object") and
            (.env_var and .label) and
            (.env_var | test("^[A-Za-z_][A-Za-z0-9_]*$"))
        )
    ' "$SECRETS_MAP_FILE" >/dev/null 2>&1; then
        echo "Invalid map file (expected JSON with entries array): $SECRETS_MAP_FILE" >&2
        echo "Each entry must include env_var/label, and env_var must be a valid shell identifier." >&2
        exit 1
    fi
}

# Used by the restore flow to bootstrap the map file.
ensure_map_file() {
    if [[ -f "$SECRETS_MAP_FILE" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$SECRETS_MAP_FILE")"
    cat >"$SECRETS_MAP_FILE" <<'EOF'
{
  "entries": []
}
EOF
}

resolve_owner() {
    local owner="$1"
    if [[ -z "$owner" || "$owner" == "__USER__" ]]; then
        if [[ -n "${USER:-}" ]]; then
            printf '%s' "$USER"
        else
            id -un
        fi
    else
        printf '%s' "$owner"
    fi
}

normalize_owner_template() {
    local owner="$1"
    if [[ -z "$owner" || (-n "${USER:-}" && "$owner" == "$USER") ]]; then
        printf '%s' "__USER__"
    else
        printf '%s' "$owner"
    fi
}

# Emit map entries as tab-separated lines: env_var \t label \t owner \t note
emit_map_entries() {
    jq -r '
    (.entries // .) | if type == "array" then . else [] end | .[] |
    select(type == "object") |
    select(.env_var and .label) |
    [.env_var, .label, (.owner // ""), (.note // "")] |
    map(tostring) | join("\t")
  ' "$SECRETS_MAP_FILE"
}

# Callback receives: env_var label owner note
for_each_map_entry() {
    local callback="$1"

    while IFS=$'\t' read -r env_var label owner note; do
        [[ -z "$env_var" || -z "$label" ]] && continue
        owner="$(resolve_owner "$owner")"
        "$callback" "$env_var" "$label" "$owner" "$note"
    done < <(emit_map_entries)
}

# Returns 1 if not found.
find_entry_by_env_var() {
    local target="$1"
    while IFS=$'\t' read -r env_var label owner note; do
        [[ -z "$env_var" || -z "$label" ]] && continue
        if [[ "$env_var" == "$target" ]]; then
            owner="$(resolve_owner "$owner")"
            printf '%s\t%s\t%s\t%s\n' "$env_var" "$label" "$owner" "$note"
            return 0
        fi
    done < <(emit_map_entries)

    return 1
}

# Returns 1 (without error) if the entry is already present.
ensure_map_entry() {
    local env_var="$1"
    local label="$2"
    local owner_template="$3"
    local note="${4:-}"
    local tmp_map

    if jq -e \
        --arg env_var "$env_var" \
        --arg label "$label" \
        '
        (.entries // .) as $entries |
        ($entries | if type == "array" then . else [] end) as $arr |
        any($arr[]; .env_var == $env_var and .label == $label)
    ' "$SECRETS_MAP_FILE" >/dev/null 2>&1; then
        return 1
    fi

    tmp_map="$(mktemp)"
    jq \
        --arg env_var "$env_var" \
        --arg label "$label" \
        --arg owner "$owner_template" \
        --arg note "$note" \
        '
        (.entries // .) as $entries |
        ($entries | if type == "array" then . else [] end) as $arr |
        {
            entries: (
                $arr + [{
                    env_var: $env_var,
                    label: $label,
                    owner: $owner,
                    note: $note
                }]
            )
        }
    ' "$SECRETS_MAP_FILE" >"$tmp_map"
    mv "$tmp_map" "$SECRETS_MAP_FILE"
    return 0
}

#!/usr/bin/env bash
set -euo pipefail

# Pluggable secrets storage abstraction.
# Supports macOS Keychain (`security`) and pass password store (`pass`).

DOTFILES_SECRETS_STORE="${DOTFILES_SECRETS_STORE:-auto}"
DOTFILES_PASS_PREFIX="${DOTFILES_PASS_PREFIX:-dotfiles}"

detect_store() {
    case "$DOTFILES_SECRETS_STORE" in
        security | pass) ;;
        auto | "")
            if command -v security > /dev/null 2>&1; then
                DOTFILES_SECRETS_STORE="security"
            elif command -v pass > /dev/null 2>&1; then
                DOTFILES_SECRETS_STORE="pass"
            else
                echo "No supported secrets store found. Install macOS 'security' (default) or 'pass'." >&2
                exit 1
            fi
            ;;
        *)
            echo "Invalid DOTFILES_SECRETS_STORE: $DOTFILES_SECRETS_STORE" >&2
            exit 1
            ;;
    esac
}

require_store() {
    case "$DOTFILES_SECRETS_STORE" in
        security) require_command security ;;
        pass) require_command pass ;;
        *)
            echo "Unsupported store: $DOTFILES_SECRETS_STORE" >&2
            exit 1
            ;;
    esac
}

pass_secret_path() {
    local label="$1"
    local owner="$2"
    printf '%s/%s/%s' "$DOTFILES_PASS_PREFIX" "$label" "$owner"
}

secret_exists() {
    local label="$1"
    local owner="$2"

    case "$DOTFILES_SECRETS_STORE" in
        security)
            security find-generic-password -a "$owner" -s "$label" > /dev/null 2>&1
            ;;
        pass)
            pass show "$(pass_secret_path "$label" "$owner")" > /dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

secret_get() {
    local label="$1"
    local owner="$2"

    case "$DOTFILES_SECRETS_STORE" in
        security)
            security find-generic-password -a "$owner" -s "$label" -w 2> /dev/null || true
            ;;
        pass)
            pass show "$(pass_secret_path "$label" "$owner")" 2> /dev/null | awk 'NR==1{print; exit}' || true
            ;;
        *)
            return 1
            ;;
    esac
}

secret_set() {
    local label="$1"
    local owner="$2"
    local value="$3"

    case "$DOTFILES_SECRETS_STORE" in
        security)
            security add-generic-password -a "$owner" -s "$label" -w "$value" -U > /dev/null
            ;;
        pass)
            printf '%s\n' "$value" | pass insert -m -f "$(pass_secret_path "$label" "$owner")" > /dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

secret_delete() {
    local label="$1"
    local owner="$2"

    case "$DOTFILES_SECRETS_STORE" in
        security)
            security delete-generic-password -a "$owner" -s "$label" > /dev/null 2>&1 || true
            ;;
        pass)
            pass rm -f "$(pass_secret_path "$label" "$owner")" > /dev/null 2>&1 || true
            ;;
        *)
            return 1
            ;;
    esac
}

#!/usr/bin/env bash
set -euo pipefail

# Pluggable secrets storage abstraction.
# Supports macOS Keychain (`security`) and pass password store (`pass`).
#
# @global DOTFILES_SECRETS_BACKEND - explicit backend choice (auto|security|pass)
# @global DOTFILES_PASS_PREFIX     - path prefix for pass entries
# @global SECRET_BACKEND           - resolved backend after detect_backend()
# @uses require_cmd from lib/platform.sh

DOTFILES_SECRETS_BACKEND="${DOTFILES_SECRETS_BACKEND:-auto}"
DOTFILES_PASS_PREFIX="${DOTFILES_PASS_PREFIX:-dotfiles-secrets}"
SECRET_BACKEND=""

detect_backend() {
    case "$DOTFILES_SECRETS_BACKEND" in
        security | pass)
            SECRET_BACKEND="$DOTFILES_SECRETS_BACKEND"
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
            echo "Invalid DOTFILES_SECRETS_BACKEND: $DOTFILES_SECRETS_BACKEND" >&2
            exit 1
            ;;
    esac
}

require_backend() {
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
    local service="$1"
    local account="$2"
    printf '%s/%s/%s' "$DOTFILES_PASS_PREFIX" "$service" "$account"
}

secret_exists() {
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

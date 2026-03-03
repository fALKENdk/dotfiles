#!/usr/bin/env bash
set -euo pipefail

# Encrypt/decrypt helpers using openssl AES-256-CBC + PBKDF2.

ensure_passphrase() {
    if [[ -z "${DOTFILES_BACKUP_PASSPHRASE:-}" ]]; then
        read -rsp "Enter backup passphrase: " DOTFILES_BACKUP_PASSPHRASE
        echo
        export DOTFILES_BACKUP_PASSPHRASE
    fi
}

ensure_passphrase_with_confirmation() {
    if [[ -n "${DOTFILES_BACKUP_PASSPHRASE:-}" ]]; then
        return 0
    fi

    read -rsp "Enter backup passphrase: " DOTFILES_BACKUP_PASSPHRASE
    echo
    local confirmation
    read -rsp "Confirm backup passphrase: " confirmation
    echo

    if [[ "$DOTFILES_BACKUP_PASSPHRASE" != "$confirmation" ]]; then
        echo "Passphrases do not match." >&2
        exit 1
    fi

    export DOTFILES_BACKUP_PASSPHRASE
}

encrypt_file() {
    local input="$1" output="$2" passphrase_variable="${3:-}"

    require_command openssl
    if [[ -n "$passphrase_variable" && -n "${!passphrase_variable:-}" ]]; then
        openssl enc -aes-256-cbc -pbkdf2 -salt \
            -pass "env:$passphrase_variable" \
            -in "$input" -out "$output"
    else
        openssl enc -aes-256-cbc -pbkdf2 -salt -in "$input" -out "$output"
    fi
}

decrypt_file() {
    local input="$1" output="$2" passphrase_variable="${3:-}"

    require_command openssl
    if [[ -n "$passphrase_variable" && -n "${!passphrase_variable:-}" ]]; then
        openssl enc -d -aes-256-cbc -pbkdf2 -salt \
            -pass "env:$passphrase_variable" \
            -in "$input" -out "$output"
    else
        openssl enc -d -aes-256-cbc -pbkdf2 -salt -in "$input" -out "$output"
    fi
}

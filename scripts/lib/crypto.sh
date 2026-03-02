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

encrypt_file() {
    local input="$1" output="$2" passphrase_var="${3:-}"

    require_cmd openssl
    if [[ -n "$passphrase_var" && -n "${!passphrase_var:-}" ]]; then
        openssl enc -aes-256-cbc -pbkdf2 -salt \
            -pass "env:$passphrase_var" \
            -in "$input" -out "$output"
    else
        openssl enc -aes-256-cbc -pbkdf2 -salt -in "$input" -out "$output"
    fi
}

decrypt_file() {
    local input="$1" output="$2" passphrase_var="${3:-}"

    require_cmd openssl
    if [[ -n "$passphrase_var" && -n "${!passphrase_var:-}" ]]; then
        openssl enc -d -aes-256-cbc -pbkdf2 -salt \
            -pass "env:$passphrase_var" \
            -in "$input" -out "$output"
    else
        openssl enc -d -aes-256-cbc -pbkdf2 -salt -in "$input" -out "$output"
    fi
}

#!/usr/bin/env bash
set -euo pipefail

# Shared encrypt/decrypt helpers wrapping openssl AES-256-CBC + PBKDF2.
#
# @uses require_cmd from lib/platform.sh
# @see keychain-secrets.sh, local-config.sh, ssh-keys-backup.sh

# Encrypt a file with AES-256-CBC + PBKDF2.
# Prompts for passphrase interactively unless $passphrase_var is set.
#
# @param $1 input  - path to plaintext input file
# @param $2 output - path to write encrypted output
# @param $3 passphrase_var - (optional) name of env var holding the passphrase
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

# Decrypt a file encrypted with encrypt_file().
# Prompts for passphrase interactively unless $passphrase_var is set.
#
# @param $1 input  - path to encrypted input file
# @param $2 output - path to write decrypted output
# @param $3 passphrase_var - (optional) name of env var holding the passphrase
decrypt_file() {
    local input="$1" output="$2" passphrase_var="${3:-}"

    require_cmd openssl
    if [[ -n "$passphrase_var" && -n "${!passphrase_var:-}" ]]; then
        openssl enc -d -aes-256-cbc -pbkdf2 \
            -pass "env:$passphrase_var" \
            -in "$input" -out "$output"
    else
        openssl enc -d -aes-256-cbc -pbkdf2 -in "$input" -out "$output"
    fi
}

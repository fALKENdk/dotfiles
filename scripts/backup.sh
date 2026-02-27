#!/usr/bin/env bash
set -euo pipefail

# Run all encrypted backup tasks in one command.
# Creates local-config, keychain-secrets(all), and SSH key backups in one folder.
source "$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)/lib/init.sh"

usage() {
    cat <<'EOF'
Usage:
  dotfiles backup [output_dir]
  dotfiles-backup [output_dir]

Examples:
  dotfiles backup
  dotfiles backup ~/backups/dotfiles
  DOTFILES_BACKUP_DIR=~/backups/dotfiles dotfiles backup

Notes:
  - output_dir defaults to DOTFILES_BACKUP_DIR, then to $HOME
  - file names include a shared timestamp so all artifacts match
  - passphrases can still be provided non-interactively via:
      LOCAL_CONFIG_PASSPHRASE
      KEYCHAIN_BACKUP_PASSPHRASE
      SSH_KEYS_BACKUP_PASSPHRASE
EOF
}

main() {
    local output_dir="${1:-${DOTFILES_BACKUP_DIR:-$HOME}}"
    local timestamp="${DOTFILES_BACKUP_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
    local local_backup
    local secrets_backup
    local ssh_backup

    if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        return 0
    fi

    if [[ "$#" -gt 1 ]]; then
        usage
        exit 1
    fi

    mkdir -p "$output_dir"
    output_dir="$(cd "$output_dir" && pwd)"

    local_backup="$output_dir/local-config-$timestamp.enc"
    secrets_backup="$output_dir/keychain-all-$timestamp.enc"
    ssh_backup="$output_dir/ssh-keys-$timestamp.enc"

    echo "Writing backups to: $output_dir"
    "$DOTFILES_DIR/scripts/local-config.sh" backup "$local_backup"
    "$DOTFILES_DIR/scripts/keychain-secrets.sh" backup all "$secrets_backup"
    "$DOTFILES_DIR/scripts/ssh-keys-backup.sh" backup "$ssh_backup"

    echo "All backups complete:"
    echo "  - $local_backup"
    echo "  - $secrets_backup"
    echo "  - $ssh_backup"
}

main "$@"

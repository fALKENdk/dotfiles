#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for restore workflows.

# Check for files that would be overwritten during restore.
# Prints conflicts and returns 1 if any are found and overwrite is not enabled.
#
# @param $1 overwrite  - "1" to allow overwriting, anything else to block
# @param $2 target_dir - destination directory to check against
# @param $3 env_hint   - env var name to suggest in the error message
# @param $@ files      - remaining args are relative file paths to check
check_restore_conflicts() {
    local overwrite="$1"
    local target_dir="$2"
    local env_hint="$3"
    shift 3

    [[ "$overwrite" == "1" ]] && return 0

    local conflicts=()
    local file
    for file in "$@"; do
        [[ -e "$target_dir/$file" ]] && conflicts+=("$file")
    done

    if [[ "${#conflicts[@]}" -gt 0 ]]; then
        echo "Restore aborted. Existing files would be overwritten:" >&2
        for file in "${conflicts[@]}"; do
            echo "  - $target_dir/$file" >&2
        done
        echo "Set ${env_hint}=1 to overwrite." >&2
        return 1
    fi
}

#!/usr/bin/env bash
set -euo pipefail

check_restore_conflicts() {
    local overwrite="$1"
    local target_directory="$2"
    shift 2

    [[ "$overwrite" == "1" ]] && return 0

    local conflicts=()
    local file
    for file in "$@"; do
        [[ -e "$target_directory/$file" ]] && conflicts+=("$file")
    done

    if [[ "${#conflicts[@]}" -gt 0 ]]; then
        echo "Restore aborted. Existing files would be overwritten:" >&2
        for file in "${conflicts[@]}"; do
            echo "  - $target_directory/$file" >&2
        done
        echo "Use --overwrite to replace existing files." >&2
        return 1
    fi
}

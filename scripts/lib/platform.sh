#!/usr/bin/env bash
set -euo pipefail

# Platform detection and dependency checks.

# Print the normalized platform name to stdout.
#
# @return stdout - "macos" | "linux"
# @throws exits 1 on unsupported platform
detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        *)
            echo "Unsupported platform: $(uname -s)" >&2
            return 1
            ;;
    esac
}

# Assert that a command exists on PATH or exit.
#
# @param $1 cmd - command name to check
# @throws exits 1 if command is missing
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd" >&2
        exit 1
    fi
}

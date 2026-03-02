#!/usr/bin/env bash
set -euo pipefail

# Platform detection, dependency checks, and Homebrew environment activation.

# Print the normalized platform name to stdout.
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
require_cmd() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

# Activate the Homebrew shell environment if brew is installed.
# Tries standard installation paths when brew is not yet on PATH.
activate_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
        return 0
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

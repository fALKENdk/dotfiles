#!/usr/bin/env bash
set -euo pipefail

render_tabular() {
    if command -v column > /dev/null 2>&1; then
        column -t -s $'\t'
    else
        cat
    fi
}

#!/usr/bin/env bash

REAL_DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_test_env() {
    TEST_HOME="$(mktemp -d)"
    TEST_DOTFILES="$(mktemp -d)"

    tar -cf - \
        --exclude='./.git' \
        --exclude='./local' \
        --exclude='./tests' \
        -C "$REAL_DOTFILES_DIR" . | tar -xf - -C "$TEST_DOTFILES"

    export HOME="$TEST_HOME"
    mkdir -p "$TEST_HOME/.ssh"
}

teardown_test_env() {
    rm -rf "${TEST_HOME:-}" "${TEST_DOTFILES:-}"
}

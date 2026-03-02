#!/usr/bin/env bats

setup() {
    load test_helper
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "symlinks skips gitconfig when local/git/.gitconfig missing" {
    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipped: ~/.gitconfig"* ]]
    [ ! -e "$HOME/.gitconfig" ]
}

@test "symlinks skips npmrc when local/npm/.npmrc missing" {
    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipped: ~/.npmrc"* ]]
    [ ! -e "$HOME/.npmrc" ]
}

@test "symlinks generates gitconfig from base only" {
    "$TEST_DOTFILES/scripts/local.sh" init

    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ -f "$HOME/.gitconfig" ]
    [[ "$output" == *"Generated: ~/.gitconfig"* ]]

    grep -q 'autocrlf = input' "$HOME/.gitconfig"
    grep -q 'excludesfile = ~/.gitignore_global' "$HOME/.gitconfig"
    ! grep -q 'includeIf' "$HOME/.gitconfig"
    ! grep -q '\[include\]' "$HOME/.gitconfig"
}

@test "symlinks generates gitconfig with github includeIf" {
    "$TEST_DOTFILES/scripts/local.sh" init
    mkdir -p "$TEST_DOTFILES/local/git"
    printf '[user]\n    name = Test\n    email = test@github.com\n' \
        >"$TEST_DOTFILES/local/git/.gitconfig-github"

    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ -f "$HOME/.gitconfig" ]
    [ -L "$HOME/.gitconfig-github" ]

    grep -q 'includeIf "hasconfig:remote.\*.url:git@github.com:\*/\*\*"' "$HOME/.gitconfig"
    grep -q 'includeIf "hasconfig:remote.\*.url:https://github.com/\*/\*\*"' "$HOME/.gitconfig"
    grep -q 'path = ~/.gitconfig-github' "$HOME/.gitconfig"
}

@test "symlinks generates gitconfig with azure-devops includeIf" {
    "$TEST_DOTFILES/scripts/local.sh" init
    mkdir -p "$TEST_DOTFILES/local/git"
    printf '[user]\n    name = Test\n    email = test@company.com\n' \
        >"$TEST_DOTFILES/local/git/.gitconfig-azure-devops"

    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ -f "$HOME/.gitconfig" ]
    [ -L "$HOME/.gitconfig-azure-devops" ]

    grep -q 'includeIf "hasconfig:remote.\*.url:git@ssh.dev.azure.com:\*/\*\*"' "$HOME/.gitconfig"
    grep -q 'includeIf "hasconfig:remote.\*.url:https://dev.azure.com/\*/\*\*"' "$HOME/.gitconfig"
    grep -q 'path = ~/.gitconfig-azure-devops' "$HOME/.gitconfig"
}

@test "symlinks generates gitconfig with plain include for unknown provider" {
    "$TEST_DOTFILES/scripts/local.sh" init
    mkdir -p "$TEST_DOTFILES/local/git"
    printf '[user]\n    name = Test\n    email = test@custom.com\n' \
        >"$TEST_DOTFILES/local/git/.gitconfig-custom"

    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ -f "$HOME/.gitconfig" ]
    [ -L "$HOME/.gitconfig-custom" ]

    grep -q '\[include\]' "$HOME/.gitconfig"
    grep -q 'path = ~/.gitconfig-custom' "$HOME/.gitconfig"
    ! grep -q 'includeIf' "$HOME/.gitconfig"
}

@test "symlinks generates npmrc from base only" {
    "$TEST_DOTFILES/scripts/local.sh" init

    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ -f "$HOME/.npmrc" ]
    [[ "$output" == *"Generated: ~/.npmrc (settings only)"* ]]

    grep -q 'update-notifier=false' "$HOME/.npmrc"
}

@test "symlinks generates npmrc with registry additions" {
    "$TEST_DOTFILES/scripts/local.sh" init
    mkdir -p "$TEST_DOTFILES/local/npm"
    echo '//registry.example.com/:_authToken=${NPM_TOKEN}' \
        >"$TEST_DOTFILES/local/npm/.npmrc-registries"

    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ -f "$HOME/.npmrc" ]
    [[ "$output" == *"Generated: ~/.npmrc (settings + local additions)"* ]]

    grep -q 'update-notifier=false' "$HOME/.npmrc"
    grep -q 'registry.example.com' "$HOME/.npmrc"
}

@test "symlinks creates gitignore_global link" {
    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ -L "$HOME/.gitignore_global" ]
    [ "$(readlink "$HOME/.gitignore_global")" = "$TEST_DOTFILES/git/.gitignore_global" ]
}

@test "symlinks is idempotent" {
    "$TEST_DOTFILES/scripts/local.sh" init
    "$TEST_DOTFILES/scripts/symlinks.sh"

    local gitconfig_before npmrc_before
    gitconfig_before="$(cat "$HOME/.gitconfig")"
    npmrc_before="$(cat "$HOME/.npmrc")"

    run "$TEST_DOTFILES/scripts/symlinks.sh"

    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.gitconfig")" = "$gitconfig_before" ]
    [ "$(cat "$HOME/.npmrc")" = "$npmrc_before" ]
}

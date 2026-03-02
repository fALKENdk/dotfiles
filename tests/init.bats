#!/usr/bin/env bats

setup() {
    load test_helper
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "init seeds only SEED_FILES" {
    run "$TEST_DOTFILES/scripts/local.sh" init

    [ "$status" -eq 0 ]

    [ -f "$TEST_DOTFILES/local/git/.gitconfig" ]
    [ -f "$TEST_DOTFILES/local/npm/.npmrc" ]
    [ -f "$TEST_DOTFILES/local/secrets/secrets-map.json" ]

    [ ! -f "$TEST_DOTFILES/local/git/.gitconfig-github" ]
    [ ! -f "$TEST_DOTFILES/local/git/.gitconfig-azure-devops" ]
    [ ! -f "$TEST_DOTFILES/local/npm/.npmrc-registries" ]
}

@test "init is idempotent" {
    "$TEST_DOTFILES/scripts/local.sh" init

    local gitconfig_before npmrc_before
    gitconfig_before="$(cat "$TEST_DOTFILES/local/git/.gitconfig")"
    npmrc_before="$(cat "$TEST_DOTFILES/local/npm/.npmrc")"

    run "$TEST_DOTFILES/scripts/local.sh" init

    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped 3 existing"* ]]

    [ "$(cat "$TEST_DOTFILES/local/git/.gitconfig")" = "$gitconfig_before" ]
    [ "$(cat "$TEST_DOTFILES/local/npm/.npmrc")" = "$npmrc_before" ]
}

@test "init does not overwrite existing files" {
    mkdir -p "$TEST_DOTFILES/local/git"
    echo "custom config" >"$TEST_DOTFILES/local/git/.gitconfig"

    run "$TEST_DOTFILES/scripts/local.sh" init

    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_DOTFILES/local/git/.gitconfig")" = "custom config" ]
    [[ "$output" == *"exists: git/.gitconfig"* ]]
}

@test "init seeds content matching local.example" {
    "$TEST_DOTFILES/scripts/local.sh" init

    diff -q \
        "$TEST_DOTFILES/local.example/git/.gitconfig" \
        "$TEST_DOTFILES/local/git/.gitconfig"

    diff -q \
        "$TEST_DOTFILES/local.example/npm/.npmrc" \
        "$TEST_DOTFILES/local/npm/.npmrc"

    diff -q \
        "$TEST_DOTFILES/local.example/secrets/secrets-map.json" \
        "$TEST_DOTFILES/local/secrets/secrets-map.json"
}
